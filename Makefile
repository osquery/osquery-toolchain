all:

# the --load pushes the build into the local docker cache. But that's
# broken for local docker. So we need to --push to get it to a
# registry to actually use it. Else it goes no where. Testing in my
# personal space
containers:
	docker buildx build --platform linux/amd64,linux/arm64 --push -t osquery/builder .

arm:
	docker buildx build --platform linux/arm64 --load -t directionless/osqbuildbeta:$@ .
x86:
	docker buildx build --platform linux/amd64 --load -t directionless/osqbuildbeta:$@ .
