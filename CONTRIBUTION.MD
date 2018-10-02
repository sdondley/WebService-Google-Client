# Contribution guidelines

This module is packaged by [Dist::Zilla](http://dzil.org/)

Firstly install it with plugins:

```
sudo cpanm Dist::Zilla
dzil authordeps --missing | sudo cpanm
```

After changing some code run:


NB to run tests against a live account:
to run live tests in /xt you can set the config file and email address using the ENVironment vars

    export GOOGLE_TOKENSFILE=<FULL PATH TO JSON FILE GENERATED WITH goauth CLI UTILITY >
    export GMAIL_FOR_TESTING=<GOOGLE EMAIL ADDRESS OF TEST ACCOUNT HOLDER>

```
dzil test
```

```
sudo dzil install # optionally, to test changes in live
```

To release module on metacpan:

1. change version in dist.ini

2. run `dzil release`
