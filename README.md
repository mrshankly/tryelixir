# Try Elixir

[![Build Status](https://travis-ci.org/tryelixir/tryelixir.png?branch=master)](https://travis-ci.org/tryelixir/tryelixir)

This is meant to be an introduction to Elixir, not a normal Elixir REPL.
Data is deleted after 5 minutes of idle and many Elixir modules are restricted for security
reasons. Try Elixir concept and design is inspired by [Try Haskell](http://tryhaskell.org/) and
[Try Clojure](http://tryclj.com/). It's written in JavaScript and Elixir with [dynamo](https://github.com/elixir-lang/dynamo)
and Chris Done's [jquery-console](https://github.com/chrisdone/jquery-console).

## How to run

    MIX_ENV=prod mix do deps.get, server

Disclamer: Modules and functions are white-listed, but beware, random code might be able to run on your machine,
be careful.

## Translations

If you wish to translate Try Elixir, please follow the [Translation Guide](https://github.com/tryelixir/tryelixir/blob/master/TRANSLATION.md).

## License

* Tryelixir source code is released under the MIT License, see [LICENSE](https://github.com/tryelixir/tryelixir/blob/master/LICENSE) for more details.
