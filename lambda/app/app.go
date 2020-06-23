// Package app provides the underlying functionality for the grace-ansible-lambda
package app

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/lambdacontext"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/client"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	env "github.com/caarlos0/env/v6"
)

// Config holds all variables read from the ENV
type Config struct {
	Region             string   `env:"REGION" envDefault:"us-east-1"`
	ImageID            string   `env:"IMAGE_ID" envDefault:""`
	InstanceType       string   `env:"INSTANCE_TYPE" envDefault:"t2.micro"`
	InstanceProfileArn string   `env:"PROFILE_ARN" envDefault:""`
	Bucket             string   `env:"USERDATA_BUCKET" envDefault:""`
	Key                string   `env:"USERDATA_KEY" envDefault:""`
	SubnetID           string   `env:"SUBNET_ID" envDefault:""`
	SecurityGroupIds   []string `env:"SECURITY_GROUP_IDS" envSeparator:","`
}

// HasUserData returns true if both Config Bucket and Key are greater
// than zero in length
func (a *Config) HasUserData() bool {
	return len(a.Bucket) > 0 && len(a.Key) > 0
}

// Payload holds the structure used to trigger this lambda
type Payload struct {
	Method     string `json:"method"`
	InstanceID string `json:"instance_id"`
}

// App is a wrapper for running Lambda
type App struct {
	ctx *lambdacontext.LambdaContext
	cfg *Config
}

// New creates a new App
func New() (*App, error) {
	a := &App{
		cfg: &Config{},
	}
	err := env.Parse(a.cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to parse ENV: %v", err)
	}
	return a, nil
}

// Run executes the lambda functionality
func (a *App) Run(ctx context.Context, p *Payload) error {
	a.ctx, _ = lambdacontext.FromContext(ctx)
	if strings.EqualFold(p.Method, "cleanup") {
		return a.cleanup(p)
	}

	return a.startup()
}

func (a *App) startup() error {
	sess, err := session.NewSession(&aws.Config{Region: aws.String(a.cfg.Region)})
	if err != nil {
		return fmt.Errorf("failed to get AWS Session: %v", err)
	}

	locked, err := a.acquireLock(sess, a.cfg.Bucket, "ansible_lock")
	if err != nil {
		return fmt.Errorf("failed to acquire lock: %v", err)
	}

	if !locked {
		fmt.Printf("another lambda already has the ansible_lock\n")
		return nil
	}

	if len(a.cfg.ImageID) == 0 {
		a.cfg.ImageID, err = getLatestImageID(sess)
		if err != nil {
			return err
		}
	}

	var userData []byte
	if a.cfg.HasUserData() {
		userData, err = readUserData(sess, a.cfg.Bucket, a.cfg.Key)
		if err != nil {
			return err
		}
	}

	instance, err := a.createEC2(sess, string(userData))
	if err != nil {
		return err
	}

	err = a.waitForEC2(sess, aws.StringValue(instance.InstanceId))
	if err != nil {
		return err
	}

	if len(a.cfg.InstanceProfileArn) > 0 {
		err = a.associateProfile(sess, aws.StringValue(instance.InstanceId))
		if err != nil {
			return err
		}
	}

	return nil
}

func (a *App) associateProfile(cfg client.ConfigProvider, instanceID ...string) error {
	svc := ec2.New(cfg)
	for _, id := range instanceID {
		_, err := svc.AssociateIamInstanceProfile(&ec2.AssociateIamInstanceProfileInput{
			IamInstanceProfile: &ec2.IamInstanceProfileSpecification{
				Arn: aws.String(a.cfg.InstanceProfileArn),
			},
			InstanceId: aws.String(id),
		})
		if err != nil {
			return fmt.Errorf("failed to associate instance profile: %v", err)
		}
	}
	return nil
}

func (a *App) acquireLock(cfg client.ConfigProvider, bucket, key string) (bool, error) {
	if existsLock(cfg, bucket, key) {
		return false, nil
	}

	err := setLock(cfg, bucket, key, a.ctx.AwsRequestID)
	if err != nil {
		return false, err
	}

	reqID, err := readLock(cfg, bucket, key)
	if err != nil {
		return false, err
	}

	if reqID != a.ctx.AwsRequestID {
		return false, nil
	}

	return true, nil
}

func setLock(cfg client.ConfigProvider, bucket, key, data string) error {
	uploader := s3manager.NewUploader(cfg)
	buf := &bytes.Buffer{}
	buf.WriteString(data)

	_, err := uploader.Upload(&s3manager.UploadInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
		Body:   buf,
	})
	if err != nil {
		return fmt.Errorf("failed to upload file, %v", err)
	}
	return nil
}

func existsLock(cfg client.ConfigProvider, bucket, key string) bool {
	svc := s3.New(cfg)
	_, err := svc.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	return err == nil
}

func readLock(cfg client.ConfigProvider, bucket, key string) (string, error) {
	svc := s3manager.NewDownloader(cfg)
	buf := &aws.WriteAtBuffer{}
	_, err := svc.Download(buf, &s3.GetObjectInput{
		Bucket: &bucket,
		Key:    &key,
	})
	if err != nil {
		return "", fmt.Errorf("failed to download lock from %s/%s", bucket, key)
	}
	return string(buf.Bytes()), nil
}

func readUserData(cfg client.ConfigProvider, bucket, key string) ([]byte, error) {
	dl := s3manager.NewDownloader(cfg)

	buf := &aws.WriteAtBuffer{}
	_, err := dl.Download(buf, &s3.GetObjectInput{
		Bucket: &bucket,
		Key:    &key,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to download UserData from %s/%s", bucket, key)
	}
	return buf.Bytes(), nil
}

func nilIfEmpty(value string) *string {
	if len(value) == 0 {
		return nil
	}
	return &value
}

func (a *App) createEC2(cfg client.ConfigProvider, userData string) (*ec2.Instance, error) {
	svc := ec2.New(cfg)

	input := &ec2.RunInstancesInput{
		ImageId:      aws.String(a.cfg.ImageID),
		InstanceType: aws.String(a.cfg.InstanceType),
		MinCount:     aws.Int64(1),
		MaxCount:     aws.Int64(1),
	}

	sEnc := base64.StdEncoding.EncodeToString([]byte(userData))
	input.UserData = nilIfEmpty(sEnc)
	input.SubnetId = nilIfEmpty(a.cfg.SubnetID)

	if len(a.cfg.SecurityGroupIds) > 0 {
		input.SecurityGroupIds = aws.StringSlice(a.cfg.SecurityGroupIds)
	}

	output, err := svc.RunInstances(input)
	if err != nil {
		return nil, fmt.Errorf("failed to create EC2 instance: %v", err)
	}

	return output.Instances[0], nil
}

func (a *App) waitForEC2(cfg client.ConfigProvider, instanceID ...string) error {
	svc := ec2.New(cfg)
	for {
		time.Sleep(1 * time.Second)
		output, err := svc.DescribeInstanceStatus(&ec2.DescribeInstanceStatusInput{
			InstanceIds: aws.StringSlice(instanceID),
		})
		if err != nil {
			fmt.Printf("failed to describe instance statuses: %v\n", err)
			continue
		}
		status := aws.StringValue(output.InstanceStatuses[0].InstanceState.Name)
		if strings.EqualFold(status, "running") {
			return nil
		}
		if strings.EqualFold(status, "terminated") || strings.EqualFold(status, "shutting-down") {
			return fmt.Errorf("failed to wait for EC2 instance: %s -> %v", instanceID[0], err)
		}
	}
}

func (a *App) cleanup(p *Payload) error {
	sess, err := session.NewSession(&aws.Config{Region: aws.String(a.cfg.Region)})
	if err != nil {
		return fmt.Errorf("failed to get AWS Session: %v", err)
	}

	err = removeEC2(sess, p.InstanceID)
	if err != nil {
		return err
	}

	return nil
}

func getFilters(m map[string]string) (filters []*ec2.Filter) {
	for k, v := range m {
		filters = append(filters, &ec2.Filter{
			Name:   aws.String(k),
			Values: []*string{aws.String(v)},
		})
	}
	return
}

func filterLatestImageID(images []*ec2.Image) (imageID string) {
	var selected *ec2.Image
	var latest time.Time
	for _, i := range images {
		t, err := time.Parse(time.RFC3339, aws.StringValue(i.CreationDate))
		if err != nil {
			fmt.Printf("time.Parse failed: %v\n", err)
			continue
		}
		if selected == nil {
			selected = i
			latest = t
			continue
		}
		if t.After(latest) {
			selected = i
			latest = t
		}
	}
	if selected != nil {
		imageID = aws.StringValue(selected.ImageId)
	}
	return
}

func getLatestImageID(cfg client.ConfigProvider) (string, error) {
	svc := ec2.New(cfg)

	filters := getFilters(map[string]string{
		"name":                             "amzn-*",
		"architecture":                     "x86_64",
		"virtualization-type":              "hvm",
		"block-device-mapping.volume-type": "gp2",
	})

	output, err := svc.DescribeImages(&ec2.DescribeImagesInput{
		Filters: filters,
	})
	if err != nil {
		return "", fmt.Errorf("failed to get Image ID: %v", err)
	}

	latest := filterLatestImageID(output.Images)

	return latest, nil
}

func removeEC2(cfg client.ConfigProvider, instanceID ...string) error {
	svc := ec2.New(cfg)

	_, err := svc.TerminateInstances(&ec2.TerminateInstancesInput{
		InstanceIds: aws.StringSlice(instanceID),
	})
	if err != nil {
		return fmt.Errorf("failed to terminate EC2 instance: %v", err)
	}
	return nil
}
