## Run Quick Bench or Build Bench locally

To launch Quick Bench, run `./quick-bench`. To launch Build Bench, run `./build-bench`.

A folder called `data` that contains cache data will automatically be created in the directory where the script is run.

Build as follows: 
```bash
docker buildx build --platform linux/amd64,linux/arm64 -f Dockerfile -t johnco3/bench-runner:latest --push .
```