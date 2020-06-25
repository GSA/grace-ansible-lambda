package app

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/client"
	"github.com/aws/aws-sdk-go/aws/ec2metadata"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/lambda"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	env "github.com/caarlos0/env/v6"
)

type Vars struct {
	Region      string `env:"REGION" envDefault:"us-east-1"`
	Bucket      string `env:"BUCKET,required"`
	Prefix      string `env:"BUCKET_PREFIX" envDefault:"ansible"`
	OutDir      string `env:"OUTPUT_DIR" envDefault:"/tmp"`
	FuncName    string `env:"FUNC_NAME"`
	HostsFile   string `env:"HOSTS_FILE"`
	SiteFile    string `env:"SITE_FILE"`
	AnsiblePath string `env:"ANSIBLE_PATH" envDefault:"ansible"`
}

// Runner holds the state for the runner
type Runner struct {
	ident *ec2metadata.EC2InstanceIdentityDocument
	vars  *Vars
	cfg   client.ConfigProvider
}

// New returns an instantiated Runner
func New() (*Runner, error) {
	r := &Runner{}
	err := env.Parse(&r.vars)
	if err != nil {
		return nil, fmt.Errorf("failed to validate environment variables: %v", err)
	}
	return r, nil
}

// Run copies the files in the bucket, executes ansible against the HostsFile and SiteFile,
// then calls the lambda function passing the cleanup payload
func (r *Runner) Run() error {
	sess, err := session.NewSession(&aws.Config{Region: aws.String(r.vars.Region)})
	if err != nil {
		return fmt.Errorf("failed to get AWS Session: %v", err)
	}
	r.cfg = sess

	defer func() {
		r.getIdent()
		err = r.invokeLambda(r.vars.FuncName, "cleanup", r.ident.InstanceID)
		if err != nil {
			fmt.Printf("cleanup failed: %v\n", err)
		}
	}()

	err = r.copyS3Directory(r.vars.Bucket, r.vars.Prefix, r.vars.OutDir)
	if err != nil {
		return err
	}

	cmd := exec.Command(r.vars.AnsiblePath, "-i", r.vars.HostsFile, r.vars.SiteFile)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err = cmd.Run()
	if err != nil {
		return fmt.Errorf("failed to execute ansible: %v", err)
	}

	return nil
}

func (r *Runner) getIdent() error {
	svc := ec2metadata.New(r.cfg)
	ident, err := svc.GetInstanceIdentityDocument()
	if err != nil {
		return fmt.Errorf("failed to get instance identity document: %v", err)
	}
	r.ident = &ident
	return nil
}

type lambdaPayload struct {
	Method     string `json:"method"`
	InstanceID string `json:"instance_id"`
}

func (r *Runner) invokeLambda(funcName, method, instanceID string) error {
	svc := lambda.New(r.cfg)

	b, err := json.Marshal(&lambdaPayload{
		Method:     method,
		InstanceID: instanceID,
	})
	if err != nil {
		return fmt.Errorf("failed to marshal payload: %v", err)
	}

	_, err = svc.Invoke(&lambda.InvokeInput{
		FunctionName: aws.String(funcName),
		Payload:      b,
	})
	if err != nil {
		return fmt.Errorf("failed to invoke lambda: %s -> %v", funcName, err)
	}
	return nil
}

func (r *Runner) copyS3Directory(bucket string, prefix string, outputPath string) error {
	svc := s3manager.NewDownloader(r.cfg)

	paths, err := listS3ObjectKeys(r.cfg, bucket, prefix)
	if err != nil {
		return err
	}

	createFolders(outputPath, paths)

	objects, err := createBatches(bucket, paths, outputPath)
	if err != nil {
		return err
	}

	iter := &s3manager.DownloadObjectsIterator{Objects: objects}
	if err := svc.DownloadWithIterator(aws.BackgroundContext(), iter); err != nil {
		return err
	}
	return nil
}

func createBatches(bucket string, keys []string, outputPath string) ([]s3manager.BatchDownloadObject, error) {
	var objects []s3manager.BatchDownloadObject
	for _, k := range keys {
		path := filepath.Join(outputPath, k)
		f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0644)
		if err != nil {
			return nil, fmt.Errorf("failed to open file: %s -> %v", path, err)
		}
		obj := s3manager.BatchDownloadObject{
			Object: &s3.GetObjectInput{
				Bucket: aws.String(bucket),
				Key:    aws.String(k),
			},
			Writer: f,
		}
		objects = append(objects, obj)
	}
	return objects, nil
}

func createFolders(base string, paths []string) {
	for _, p := range paths {
		dir := filepath.Join(base, filepath.Dir(p))
		err := os.MkdirAll(dir, os.ModeDir)
		if err != nil {
			fmt.Printf("failed when creating path: %s -> %v", dir, err)
		}
	}
}

func listS3ObjectKeys(cfg client.ConfigProvider, bucket, prefix string) ([]string, error) {
	svc := s3.New(cfg)

	var keys []string
	err := svc.ListObjectsV2Pages(&s3.ListObjectsV2Input{
		Bucket: aws.String(bucket),
		Prefix: aws.String(prefix),
	}, func(page *s3.ListObjectsV2Output, lastPage bool) bool {
		for _, c := range page.Contents {
			keys = append(keys, aws.StringValue(c.Key))
		}
		return !lastPage
	})
	if err != nil {
		return nil, err
	}

	return keys, nil
}
