# pull official base image
FROM ubuntu:20.04

RUN apt-get update && apt-get upgrade -y \
    && apt-get install python3 -y\
    && apt-get install python3-pip -y\
    && apt-get install python-is-python3 \
    && pip install --upgrade pip \
    && apt-get install git -y \
    && apt-get install python3-libusb1 -y
    
RUN git clone https://github.com/micropython/micropython
RUN git clone -b v4.4.4 --recursive https://github.com/espressif/esp-idf.git 


RUN ./esp-idf/install.sh esp32
