FROM debian:bullseye

# Install basics
RUN apt-get update && apt-get install -y curl jq gnupg1 apt-transport-https dirmngr iperf3 iputils-ping bc

COPY ./speedtest.sh .
CMD ["./speedtest.sh"]
