.PHONY: test clean

test:
	python3 tests/run.py

clean:
	rm -rf .build

.PHONY: acceptance
acceptance:
	python3 tests/acceptance/run.py --all
