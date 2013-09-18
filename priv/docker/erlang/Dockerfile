FROM base

# update and install dependencies
RUN apt-get update
RUN apt-get install -y git build-essential libncurses5-dev curl m4 libssl-dev

# install erlang R16B02
RUN curl -O http://www.erlang.org/download/otp_src_R16B02.tar.gz
RUN tar xzvf otp_src_R16B02.tar.gz; cd /otp_src_R16B02; ./configure; make; make install
RUN rm -rf /otp_src_R16B02

# install rebar
RUN git clone git://github.com/rebar/rebar.git; cd rebar; ./bootstrap
RUN mv /rebar/rebar /usr/local/bin/rebar
RUN rm -rf /rebar
