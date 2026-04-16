.PHONY: setup test validate generate check all

setup:
	mix deps.get

test:
	mix test

validate:
	mix validate_rules

generate:
	mix generate_toc

check:
	mix check_rules

all: validate test generate check
