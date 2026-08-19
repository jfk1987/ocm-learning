# OCM Delivery Builder

This image is the execution container for the Woodpecker release job. It
contains OCM, Helm, Mike Farah's `yq`, and Skopeo. It is explicitly **not**
part of the target application component and may be built or pulled from the
Internet in the preparation lab.

```bash
docker build \
  --tag localhost:5000/lab/ocm-delivery:0.1.0 \
  --file ci/ocm-delivery/Dockerfile .
docker run --rm localhost:5000/lab/ocm-delivery:0.1.0 -lc \
  'ocm version && helm version && yq --version && skopeo --version'
docker push localhost:5000/lab/ocm-delivery:0.1.0
```

Reference this image in `examples/ci/ocm-delivery.yaml` for Woodpecker. Before
production use, all versions in the Dockerfile are checked and maintained like
a normal build artifact. The Dockerfile uses `TARGETARCH` so it can be built
on both `amd64` and `arm64` hosts. In the lab, it is built for the same
architecture as the k3d node.
