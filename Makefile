.PHONY: test clean

test:
	python3 tests/run.py

clean:
	rm -rf .build
