# What is this repository?

This repository is a demo for who wants to see/use some crawlers through a CLI.

## How to use?

1. Clone the repository

```
 $ git clone https://github.com/vcborsolan/cli_crawlers.git 
```

2. Install dependencies

```
 $ bundle install 
```

## Features:

1. 
```
 $ thor crawl:update_key 'TWO_CAPTCHA_KEY'
```

 * If there is no .env file it creates one and add CAPTCHA_KEY for usage in two_captcha. It is used for cheating captcha's in some crawlers.

## To do list:

1. Verify broken crawlers.
2. Connect .thor commands to module app
3. Add other existing crawlers