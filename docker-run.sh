#!/bin/bash

# I'm using this to run tryelixir with docker, you need erlang installed
cd /opt
git clone https://github.com/elixir-lang/elixir; cd elixir; make; cd ..
export PATH=`pwd`/elixir/bin:$PATH
git clone https://github.com/tryelixir/tryelixir; cd tryelixir; MIX_ENV=prod mix do deps.get, server
