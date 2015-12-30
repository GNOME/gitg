#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby -W0

$VERBOSE = nil

psep = ARGV.index("--") || 0

ARGV = ARGV[psep + 1..-1]
G_ORIG_BREW_RB = ARGV[0]

ARGV.shift

require "pathname"

G_HOMEBREW_BREW_FILE = ENV["HOMEBREW_BREW_FILE"]
G_HOMEBREW_LIBRARY_PATH = Pathname.new(G_HOMEBREW_BREW_FILE).realpath.parent.parent.join("Library", "Homebrew")

$:.unshift(G_HOMEBREW_LIBRARY_PATH.to_s)

require "global"

RUBY_PATH = Pathname.new(__FILE__)
RUBY_BIN = RUBY_PATH.dirname

module OS
  module Mac
    extend self

    alias_method :orig_sdk_path, :sdk_path

    def sdk_path
      orig_sdk_path("10.8")
    end

    def full_version
      Version.new("10.8.5")
    end

    def version
      Version.new("10.8")
    end
  end
end

require "extend/ENV/super"

module Superenv
  def effective_sysroot
    MacOS.sdk_path.to_s
  end

  def determine_optflags
    cpu = Hardware::CPU.optimization_flags.fetch(Hardware.oldest_cpu)

    "#{cpu} -mmacosx-version-min=#{OS::Mac::version}"
  end

  alias_method :orig_setup_build_environment, :setup_build_environment

  def setup_build_environment(formula=nil)
    if self["GITG_SHELL"]
      orig_setup_build_environment(formula || Formulary.factory("gnome/gitg/gitg"))

      prepend_path "PATH", self["HOME"] + "/.local/bin"

      self["PS1_EXTRA"] = "\\[\\033[0;35m\\](gitg-brew)\\[\\033[0m\\] "
      self["XDG_DATA_DIRS"] = self["HOMEBREW_PREFIX"] + "/share"

      prepend_path "PKG_CONFIG_PATH", self["HOMEBREW_PREFIX"] + "/lib/pkgconfig"
      prepend_path "PKG_CONFIG_PATH", self["HOMEBREW_PREFIX"] + "/share/pkgconfig"
    else
      orig_setup_build_environment(formula)
    end
  end
end

load(G_ORIG_BREW_RB)
