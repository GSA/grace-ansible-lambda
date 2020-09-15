// Package app provides the underlying functionality for the grace-ansible-lambda
package app

import (
	"context"
	"encoding/base64"
	"fmt"

	"github.com/aws/aws-lambda-go/lambdacontext"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/client"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/secretsmanager"

	env "github.com/caarlos0/env/v6"
)

// Config holds all variables read from the ENV
type Config struct {
	Region      string `env:"REGION" envDefault:"us-east-1"`
	KeyPairName string `env:"KEYPAIR_NAME" envDefault:""`
	SecretName  string `env:"SECRET_NAME" envDefault:"ansible-key-pairs"`
}

// App is a wrapper for running Lambda
type App struct {
	ctx *lambdacontext.LambdaContext
	cfg *Config
}

// New creates a new App
func New() (*App, error) {
	cfg := Config{}
	a := &App{
		cfg: &cfg,
	}
	err := env.Parse(&cfg)
	if err != nil {
		return nil, fmt.Errorf("failed to parse ENV: %v", err)
	}
	return a, nil
}

// Run executes the lambda functionality
func (a *App) Run(ctx context.Context) error {
	a.ctx, _ = lambdacontext.FromContext(ctx)
	return a.startup()
}

func (a *App) startup() error {
	sess, err := session.NewSession(&aws.Config{Region: aws.String(a.cfg.Region)})
	if err != nil {
		return fmt.Errorf("failed to get AWS Session: %v", err)
	}

	err = a.deleteOldKeyPair(sess)
	if err != nil {
		return fmt.Errorf("failed to delete old key pair: %v", err)
	}

	keyPair, err := a.createNewKeyPair(sess)
	if err != nil {
		return fmt.Errorf("failed to create new key pair: %v", err)
	}

	err = a.updateSecret(sess, keyPair)
	if err != nil {
		return fmt.Errorf("failed to update secret: %v", err)
	}

	return nil
}

func (a *App) deleteOldKeyPair(cfg client.ConfigProvider) error {
	svc := ec2.New(cfg)

	fmt.Printf("Deleting old %s key pair\n", a.cfg.KeyPairName)

	_, err := svc.DeleteKeyPair(&ec2.DeleteKeyPairInput{
		KeyName: aws.String(a.cfg.KeyPairName),
	})
	if err != nil {
		if aerr, ok := err.(awserr.Error); ok && aerr.Code() == "InvalidKeyPair.Duplicate" {
			fmt.Printf("Key pair %s does not exist.", a.cfg.KeyPairName)
			return nil
		}
	}
	return err
}

func (a *App) createNewKeyPair(cfg client.ConfigProvider) (*ec2.CreateKeyPairOutput, error) {
	svc := ec2.New(cfg)

	fmt.Printf("Creating new %s key pair\n", a.cfg.KeyPairName)

	result, err := svc.CreateKeyPair(&ec2.CreateKeyPairInput{
		KeyName: aws.String(a.cfg.KeyPairName),
	})
	if err != nil {
		return nil, err
	}
	return result, err
}

func (a *App) updateSecret(cfg client.ConfigProvider, keyPair *ec2.CreateKeyPairOutput) error {
	svc := secretsmanager.New(cfg)

	fmt.Printf("Updating secret: %s", a.cfg.SecretName)

	sEnc := base64.StdEncoding.EncodeToString([]byte(*keyPair.KeyMaterial))

	_, err := svc.UpdateSecret(&secretsmanager.UpdateSecretInput{
		SecretId:     aws.String(a.cfg.SecretName),
		SecretString: aws.String(sEnc),
	})
	return err
}
