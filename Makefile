.PHONY: test clean

test:
	python3 tests/run.py

clean:
	rm -rf .build

.PHONY: acceptance
acceptance:
	python3 tests/acceptance/run.py --all

.PHONY: verify-evidence evidence-waveforms scale-quick scale-full test-evidence-tools

BW_CACHE_MODE ?= cold

verify-evidence:
	python3 tools/evidence.py verify all --current-source

evidence-waveforms:
	python3 tools/evidence.py restore waveforms

scale-quick:
	python3 tests/scale/revised_suite.py quick --cache-mode $(BW_CACHE_MODE) --output-root .build/revised

scale-full:
	python3 tools/evidence.py restore common
	python3 tests/scale/revised_suite.py full --cache-mode $(BW_CACHE_MODE) --output-root .build/revised

test-evidence-tools:
	python3 tools/test_evidence.py
	python3 tools/evidence.py restore waveforms
	python3 tools/evidence.py restore legacy-tests
	python3 tests/acceptance/test_publish.py
	python3 -m unittest discover -s tests/scale -p 'test_*.py'
