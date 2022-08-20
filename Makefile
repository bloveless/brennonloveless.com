tag = 0.2.2

.PHONY: publish
publish:
	docker buildx build --platform=linux/amd64,linux/arm64 -t bloveless/brennonloveless-com:$(tag) . --push

.PHONY: install
install: publish
	kubectl apply -f ./k8s/

