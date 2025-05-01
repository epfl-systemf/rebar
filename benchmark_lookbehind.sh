#!/bin/bash

REGEX_BRANCH="captureless-lookbehinds"
OUTFILE_FULL="results_full.csv"
OUTFILE_LB="results_lookbehind.csv"
ENGINES='^rust/regex(|-lookbehind)$|^python/re$'

# quit on error
set -e

if [ "$1" = "--install" ]
then
    # install dependencies
    apt-get update
    apt-get install -y build-essential git curl virtualenv
    exit 0
fi

# Check if git is available
if ! command -v git 2>&1 >/dev/null
then
    echo "Need git to clone repositories, please install it or run the script with --install"
    exit 1
fi

# Check if cc is available
if ! command -v cc 2>&1 >/dev/null
then
    echo "Command 'cc' not found, please install the build-essentials package or run the script with --install"
    exit 1
fi

# Check if virtualenv is available
if ! command -v virtualenv 2>&1 >/dev/null
then
    echo "Need virtualenv to create a python environment, please install it or run the script with --install"
    exit 1
fi

# make sure rustup is available and up to date
if ! command -v rustup 2>&1 >/dev/null
then
    if ! command -v curl 2>&1 >/dev/null
    then
        echo "Need curl to install rust, please install curl or install rustup manually or run the script with --install"
        exit 1
    fi
    # install rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
else
    # update existing installation
    rustup update
fi

# clone regex fork
if [ ! -d "../rust-regex" ]
then
    git clone https://github.com/epfl-systemf/rust-regex.git ../rust-regex
fi

# update repos and set toolchains
cd ../rust-regex
git checkout "$REGEX_BRANCH"
git pull
rustup override set stable
cd ../rebar
rustup override set stable

# create python environment
if [ ! -d "venv" ]
then
    virtualenv -p python3 venv
fi

# activate python environment
source venv/bin/activate

# extract regex patterns
echo "Extracting patterns from snort rules"
if [ ! -d "snortrules-snapshot-3200/rules" ]
then
    echo "Could not find snort rules, please download the snapshot 3200"
    echo "from https://snort.org/downloads#rules and extract it to './snortrules-snapshot-3200/'"
    echo "You will need to create an account to download the rules, which is free to do"
    echo "but means we cannot distribute the rules with this script"
    deactivate
    exit 1
fi
mkdir -p benchmarks/regexes/lookbehind/
python3 extract_snort_regexes.py snortrules-snapshot-3200/rules benchmarks/regexes/lookbehind/

# download haystack
echo "Downloading lookbehind benchmark haystack..."
curl https://archive.wrccdc.org/pcaps/2024/31/wrccdc.2024-02-17.084915.pcap.gz -o wrccd.pcap.gz
gunzip wrccd.pcap.gz
mv wrccd.pcap benchmarks/haystacks/imported

# build rebar
echo "Preparing benchmark..."
cargo install --path .

# build regex engines
rebar build -e "$ENGINES"

# perform sanity check
echo "Running test benchmarks..."
rebar measure -e "$ENGINES" -f '^test/' --test

# perform benchmark
echo "Running lookbehind benchmark..."
rebar measure -e "$ENGINES" -f '^lookbehind/' | tee "../$OUTFILE_LB"
echo "Running full benchmark..."
rebar measure -e "$ENGINES" | tee "../$OUTFILE_FULL"

# deactivate python environment
deactivate

echo ""
echo ""
echo "Everything done!"
