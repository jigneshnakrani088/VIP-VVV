## VIP-VVV

This allows [VVV](https://github.com/Varying-Vagrant-Vagrants/VVV) to provision a site for WordPress.com VIP development. It uses the new VVV 2 provisioning system, and implements the steps described on the VIP site [here](https://vip.wordpress.com/documentation/vip/dev-environment/).

We don't maintain the MU plugins or VIP codebase, for issues, please refer to the [VIP MU plugins](https://github.com/Automattic/vip-wpcom-mu-plugins) repository or VIP support

### Installation

To use this, modify your `vvv-custom.yml` to add the following:

```
  vip:
    repo: https://github.com/tomjn/VIP-VVV.git
    hosts:
      - vip.local
      - yoursite.vip.local
```

Then run:

```
vagrant reload --provision
```

A subdomain multisite install will be created, using the first host specified. VVV will clone this repository on provision and install all the relevant things.


#### I don't have a `vvv-custom.yml`?

You can create this with a copy `vvv-config.yml`

#### Will this work in VVV 1?

Maybe, but it's not supported, use VVV 2

### Starter Themes

In addition to all the things that come with VVV, and the shared VIP code/plugins, this adds several other items that may aid VIP development:

 - **Minimum Viable VIP** - The smallest possible theme that passes VIP code review. It provides a 404 page, a main file, and includes the needed headers, but nothing else.
 - **_s** - A copy of underscores, a popular starter theme
 - **Query Monitor** - A super useful debugging plugin
