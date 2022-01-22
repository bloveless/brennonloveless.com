tag = 0.0.1-alpha.1

.PHONY: publish
publish:
	docker build -t bloveless/brennonloveless-com:$(tag) .
	docker push bloveless/brennonloveless-com:$(tag)

.PHONY: install
install: publish
	kubectl apply -f ./k8s/

