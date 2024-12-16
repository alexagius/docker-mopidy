PROJECT=mopidy

docker-image:
	docker build . --file Dockerfile --tag aagius/mopidy:latest --progress=plain --no-cache
