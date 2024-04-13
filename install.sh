#!/bin/bash

swift build -c release && cp -f .build/release/EasyBranch /usr/local/bin/${1:-easybranch}
