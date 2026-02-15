APP_NAME ?= cloudnative-app
COMMIT_SHA ?= $(shell git rev-parse --short=12 HEAD)
AWS_REGION ?= us-east-1
AWS_ACCOUNT_ID ?= 508591325080
IMAGE_REPO ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(APP_NAME)
IMAGE ?= $(IMAGE_REPO):$(COMMIT_SHA)

.PHONY: install build test docker-build

install:
	npm install

build:
	npm run build

test:
	npm run test

docker-build:
	docker build -t $(IMAGE) -f Dockerfile .
