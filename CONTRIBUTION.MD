# Contribution guidelines

This module is packaged by [Dist::Zilla](http://dzil.org/)

Firstly install it with plugins:

```
sudo cpanm Dist::Zilla
dzil authordeps --missing | sudo cpanm
```

After changing some code run:

```
dzil test
sudo dzil install # optionally, to test changes in live
```

To release module on metacpan:

1. change version in dist.ini

2. run `dzil release`
