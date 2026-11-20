.PHONY: setup test validate generate check all

setup:
	mix deps.get

test:
	mix test

validate:
	mix shampoo.validate_rules

generate:
	mix shampoo.generate_toc

check:
	mix shampoo.check_rules

all: validate test generate check
