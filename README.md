# fs-perftest

Script to perform parameter scanning to find good OS parameters for file system performance.

[![License](https://img.shields.io/badge/License-BSD--like-lightgrey)](https://github.com/caltechlibrary/fs-perftest/blob/main/LICENSE)


## Table of contents

* [Introduction](#introduction)
* [Installation](#installation)
* [Quick start](#quick-start)
* [Usage](#usage)
* [License](#license)
* [Acknowledgments](#acknowledgments)


## Introduction

This is a script for running some common test utilities with a trivial parameter scanning approach, to explore values to improve file system performance.

## Installation

Copy the script to the file system volume to be tested.


## Quick start

Edit the top of the script to set the value of `device`.

Run the script as root and save the output somewhere. It will take a few hours to run, so put it in the background too.

```sh
./perftest > ~/output.log 2>&1 &
```


## Usage

After running the script, look through the results.


## License

Software produced by the Caltech Library is Copyright © 2024 California Institute of Technology. This software is freely distributed under a modified BSD 3-clause license. Please see the [LICENSE](LICENSE) file for more information.


## Acknowledgments

This work was funded by the California Institute of Technology Library.

<div align="center">
  <br>
  <a href="https://www.caltech.edu">
    <img width="100" height="100" alt="Caltech logo" src="https://raw.githubusercontent.com/caltechlibrary/fs-perftest/main/.graphics/caltech-round.png">
  </a>
</div>
