
Debian/Ubuntu packaging instructions
------------------------------------

```
  # Generate a source tar.gz image (from source tarball)
  export VERSION="1.2.3-4"                            # Setup version (as in changelog)
  make build-sources                                  # Get sources if missing
  cp pspdev-*-source.tgz ../pspdev_$VERSION.orig.tar.gz

  mkdir ../pspdev-$VERSION                      # Create source dir
  cd ../pspdev-$VERSION
  tar xf ../pspdev_$VERSION.orig.tar.gz         # Extract dir locally
  mv dist/debian .                              # Move debian to top level

  # Generate source deb and upload to launchpad
  dpkg-buildpackage --build=source -kemail@example.com
  dput ppa:user/repo ../pspdev_$VERSION_source.changes
```

