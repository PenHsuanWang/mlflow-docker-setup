FROM quay.io/minio/minio

# Install mlflow
RUN curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

RUN chmod +x $HOME/minio-binaries/mc
ENV PATH="$PATH:$HOME/minio-binaries/"
