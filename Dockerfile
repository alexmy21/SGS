FROM osrf/ros:foxy-desktop

# Source the ROS 2 setup script
RUN echo "source /opt/ros/foxy/setup.bash" >> /root/.bashrc

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg2 \
    ca-certificates \
    tar \
    python3-pip \
    vim

# Download and install Julia
RUN wget https://julialang-s3.julialang.org/bin/linux/x64/1.6/julia-1.6.3-linux-x86_64.tar.gz && \
    tar -xvzf julia-1.6.3-linux-x86_64.tar.gz && \
    mv julia-1.6.3 /opt/ && \
    ln -s /opt/julia-1.6.3/bin/julia /usr/local/bin/julia

# Install the RobotOS package in Julia
RUN /bin/bash -c "source /opt/ros/foxy/setup.bash && julia -e 'using Pkg; Pkg.add(\"RobotOS\")'"

# Set the working directory
WORKDIR /root