FROM erlang

# install elixir master
RUN git clone https://github.com/elixir-lang/elixir.git; cd elixir; make; make install

# get tryelixir
RUN git clone https://github.com/tryelixir/tryelixir; mix do deps.get --all, compile

# expose port
EXPOSE 80:8888

# run tryelixir
CMD cd tryelixir; MIX_ENV=prod mix server