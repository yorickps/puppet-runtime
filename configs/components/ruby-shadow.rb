component "ruby-shadow" do |pkg, settings, platform|
  pkg.url "https://github.com/apalmblad/ruby-shadow"
  pkg.ref "refs/tags/2.5.0"

  pkg.build_requires "ruby-#{settings[:ruby_version]}"
  pkg.environment "PATH", "$(PATH):/usr/ccs/bin:/usr/sfw/bin"
  pkg.environment "CONFIGURE_ARGS", '--vendor'

  if platform.is_solaris?
    if platform.architecture == 'sparc'
      pkg.environment "RUBY", settings[:host_ruby]
    end
    ruby = "#{settings[:host_ruby]} -r#{settings[:datadir]}/doc/rbconfig-#{settings[:ruby_version]}-orig.rb"
  elsif platform.is_cross_compiled?
    pkg.environment "RUBY", settings[:host_ruby]
    ruby = "#{settings[:host_ruby]} -r#{settings[:datadir]}/doc/rbconfig-#{settings[:ruby_version]}-orig.rb"
  else
    ruby = File.join(settings[:ruby_bindir], 'ruby')
  end

  # This is a disturbing workaround needed for s390x based systems, that
  # for some reason isn't encountered with our other architecture cross
  # builds. When trying to build the libshadow test cases for extconf.rb,
  # the process fails with "/opt/pl-build-tools/bin/s390x-linux-gnu-gcc:
  # error while loading shared libraries: /opt/puppetlabs/puppet/lib/libstdc++.so.6:
  # ELF file data encoding not little-endian". It will also complain in
  # the same way about libgcc. If however we temporarily move these
  # libraries out of the way, extconf.rb and the cross-compile work
  # properly. This needs to be fixed, but I've spent over a week analyzing
  # every possible angle that could cause this, from rbconfig settings to
  # strace logs, and we need to move forward on this platform.
  # FIXME: Scott Garman Jun 2016
  # Added to ppc64
  if platform.architecture == "ppc64"
    pkg.configure do
      [
        "mkdir #{settings[:libdir]}/hide",
        "mv #{settings[:libdir]}/libstdc* #{settings[:libdir]}/hide/",
        "mv #{settings[:libdir]}/libgcc* #{settings[:libdir]}/hide/"
      ]
    end
  end

  matchdata = platform.settings[:ruby_version].match /(\d+)\.(\d+)\.\d+/
  ruby_major_version = matchdata[1].to_i
  if ruby_major_version >= 3
    base = "resources/patches/ruby_32"
    # https://github.com/apalmblad/ruby-shadow/issues/26
    # if ruby-shadow gets a 3 release this should be removed
    pkg.apply_patch "#{base}/ruby-shadow-taint.patch", strip: "1"
    pkg.apply_patch "#{base}/ruby-shadow-rbconfig.patch", strip: "1"
  end

  pkg.build do
    ["#{ruby} extconf.rb",
     "#{platform[:make]} -e -j$(shell expr $(shell #{platform[:num_cores]}) + 1)"]
  end

  pkg.install do
    ["#{platform[:make]} -e -j$(shell expr $(shell #{platform[:num_cores]}) + 1) DESTDIR=/ install"]
  end

  # Undo the gross hack from the configure step
  if platform.architecture == "ppc64"
    pkg.install do
      [
        "mv #{settings[:libdir]}/hide/* #{settings[:libdir]}/",
        "rmdir #{settings[:libdir]}/hide/"
      ]
    end
  end
end
