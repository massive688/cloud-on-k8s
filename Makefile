
### Start of Autogenerated ###

# Image URL to use all building/pushing image targets
IMG ?= controller:latest

all: all-tests manager

# Run tests
unit-tests: generate fmt vet manifests
	go test -tags=unit ./pkg/... ./cmd/... -coverprofile cover.out

all-tests: generate fmt vet manifests
	go test ./pkg/... ./cmd/... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager github.com/elastic/stack-operators/cmd/manager

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./cmd/manager/main.go

# Install CRDs into a cluster
install: manifests
	kubectl --cluster=$(KUBECTL_CONFIG) apply -f config/crds

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	kubectl --cluster=$(KUBECTL_CONFIG) apply -f config/crds
	kustomize build config/default | kubectl --cluster=$(KUBECTL_CONFIG) apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests:
	go run vendor/sigs.k8s.io/controller-tools/cmd/controller-gen/main.go all

# Run go fmt against code
fmt:
	goimports -w pkg cmd

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

# Generate code
generate:
	go generate ./pkg/... ./cmd/...

# Build the docker image
docker-build: unit-test
	docker build . -t ${IMG}
	@echo "updating kustomize image patch file for manager resource"
	sed -i'' -e 's@image: .*@image: '"${IMG}"'@' ./config/default/manager_image_patch.yaml

# Push the docker image
docker-push:
	docker push ${IMG}

### End of Autogenerated ###

INSTALL_HELP = "please refer to the README.md for how to install it."
GO := $(shell command -v go)
GOIMPORTS := $(shell command -v goimports)
MINIKUBE := $(shell command -v minikube)
KUBECTL := $(shell command -v kubectl)
KUBEBUILDER := $(shell command -v kubebuilder)
DEP := $(shell command -v dep)

KUBECTL_CONFIG ?= minikube
MINIKUBE_KUBERNETES_VERSION ?= v1.12.0
MINIKUBE_MEMORY ?= 8192

.PHONY: requisites
requisites:
ifndef GO
	@ echo "-> go binary missing, $(INSTALL_HELP)"
	@ exit 1
endif
ifndef GOIMPORTS
	@ echo "-> goimports binary missing, $(INSTALL_HELP)"
	@ exit 1
endif
ifndef MINIKUBE
	@ echo "-> minikube binary missing, $(INSTALL_HELP)"
	@ exit 2
endif
ifndef KUBECTL
	@ echo "-> kubectl binary missing, $(INSTALL_HELP)"
	@ exit 3
endif
ifndef KUBEBUILDER
	@ echo "-> kubebuilder binary missing, $(INSTALL_HELP)"
	@ exit 4
endif

# dev
.PHONY: dev
dev: minikube vendor unit-tests manager install samples
	@ echo "-> Development environment started"
	@ echo "-> Run \"make run\" to start the manager process localy"

# minikube ensures that there's a local minikube environment running
.PHONY: minikube
minikube: requisites
ifneq ($(shell minikube status --format '{{.MinikubeStatus}}'),Running)
	@ echo "-> Starting minikube..."
	@ minikube start --kubernetes-version $(MINIKUBE_KUBERNETES_VERSION) --memory ${MINIKUBE_MEMORY}
else
	@ echo "-> minikube already started, skipping..."
endif

# samples pushes the samples to the configured Kubernetes cluster.
.PHONY: samples
samples: requisites generate
	@ echo "-> Pushing samples to Kubernetes cluster..."
	@ kubectl --cluster=$(KUBECTL_CONFIG) apply -f config/samples

.PHONY: vendor
vendor:
ifndef DEP
	@ echo "-> dep binary missing, $(INSTALL_HELP)"
	@ exit 5
endif
	@ echo "-> Running dep..."
	@ dep ensure
