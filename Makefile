PROJECT=mopidy

docker-image:
	docker build . --file Dockerfile --tag markusressel/mopidy:latest --progress=plain --no-cache
