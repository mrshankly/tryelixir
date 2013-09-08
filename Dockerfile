FROM base

# update and install dependencies
RUN apt-get update
RUN apt-get install -y git build-essential libncurses5-dev curl m4 libssl-dev

# install erlang R16B01
RUN curl -O http://www.erlang.org/download/otp_src_R16B01.tar.gz
RUN tar xzvf otp_src_R16B01.tar.gz; cd otp_src_R16B01; ./configure; make; make install

# install elixir master
RUN git clone https://github.com/elixir-lang/elixir.git; cd elixir; make; make install

# install rebar
RUN git clone git://github.com/rebar/rebar.git; cd rebar; ./bootstrap
RUN mv /rebar/rebar /usr/local/bin/rebar
RUN rm -rf /rebar

# get tryelixir
RUN git clone https://github.com/tryelixir/tryelixir

# expose port
EXPOSE 80:8888

# run tryelixir
CMD cd tryelixir; MIX_ENV=prod mix do deps.get --all, compile, server
