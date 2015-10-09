# Caliper
### Reviving mini-breakpad-server
Mini-breakpad-server is basically abandonded at this point.  Breakpad is still amazing technology, and people want to use it.  Caliper is intended to be a middle ground between nothing and Socorro (Mozilla's breakpad infrastructure).

## Caliper holds your breaks.
This intends to be a simple server for crash reports sent by
[google-breakpad](https://code.google.com/p/google-breakpad/).


## Features

* Collecting crash reports with minidump files.
* Simple web interface for viewing translated crash reports.
* Uploading of symbols using google's tools for breakpad (symupload).

## Run

* `npm install .` -- if this fails make sure you have node-gyp setup correctly
* `grunt`
* Put your breakpad symbols under `pool/symbols/PDBNAME/PDBUNIQUEIDENTIFIER/PDBNAMEASSYM`
* OR send a POST request to your server at /symbol_upload using googles symupload tool.
* `node lib/app.js`

## Breakpad crash sending
In the SendCrashReport function that breakpad provides, simply put "http://your.site/crash_upload".
