package main

import (
	"os"
	"log"
	"github.com/briankfitzwater/grace-ansible-lambda/runner/app"
)

func main() {
	r, err := app.New()
	if err != nil {
		log.Printf("failed to create new runner: %v\n", err)
		os.Exit(1)
	}
	err = r.Run()
	if err != nil {
		log.Printf("failed to execute runner: %v", err)
		os.Exit(1)
	}
}