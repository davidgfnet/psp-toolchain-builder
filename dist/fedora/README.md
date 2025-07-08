
Fedora packaging instructions
-----------------------------

```
  # Download all the required sources:
  make build-sources

  # Generate a src.rpm file
  rpmdev-setuptree
  cp pspdev-*-source.tgz ~/rpmbuild/SOURCES/
  cp dist/fedora/pspdev.spec ~/rpmbuild/SPECS/
  rpmbuild -bs ~/rpmbuild/SPECS/pspdev.spec
```

You can upload the binary to Copr. To generate a binary you can run:

```
  rpmbuild -ba ~/rpmbuild/SPECS/pspdev.spec
```

