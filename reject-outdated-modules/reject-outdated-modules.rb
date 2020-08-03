#!/usr/bin/env ruby

require "json"
require "net/http"
require "open3"
require "uri"
require 'pry-byebug'
require "octokit"

require File.join(File.dirname(__FILE__), "github")


NAMESPACE_DIR = "."
ORG = "ministryofjustice"
TF_MODULE_REGEX = "source.*github.com\\/#{ORG}\\/cloud-platform-terraform-.*"
ModuleUsage = Struct.new(:module, :version, :latest)


gh = GithubClient.new

def tf_files_in_pr(gh)
  gh.files_in_pr
    .grep(/\.(tf)$/)
end

def modules_used()
  modules = []
  tf_files_in_pr(gh).each do |file|
    stdout, _stderr, _status = Open3.capture3("grep #{TF_MODULE_REGEX} #{file}")
    modules << stdout.split("\n").map { |line| module_usage(line) }
  end
end

def module_usage(line)
    parts = line
      .sub(/"$/, "")
      .split("/")
  
    namespace = parts[2]
    mod, version = parts.last.split("?ref=")
  
    ModuleUsage.new( mod, version)
end



# Return a list of all module usage (module, version)
def in_use
    modules_used()
      .flatten
end

def namespaces
Dir["#{NAMESPACE_DIR}/*"]
    .find_all { |dir| FileTest.directory?(dir) }
    .map { |dir| File.basename(dir) }
end

# Takes all the ModuleUsage objects that exist, reduces to unique
# module names, and returns a hash: { module name => latest version }
def module_latest_releases(modules_in_use)
    modules_in_use
      .map { |mu| mu.module }
      .uniq
      .each_with_object({}) { |mod, hash| hash[mod] = latest_version(mod); }
end

# Takes a module name, returns the value of the last release defined in the
# corresponding github repo.
def latest_version(module_name)
    stdout, _stderr, _status= Open3.capture3("
        curl https://github.com/ministryofjustice/#{module_name}/releases/latest -Is| grep tag| rev | cut -d '/' -f1 | rev | tr -d '\r\n' ")
    stdout
end

def out_of_date_modules
    # binding.pry
    modules_in_use = in_use
    latest_releases = module_latest_releases(in_use)
  
    out_of_date_list = []
  
    # Compare the version in use to the latest version available
    modules_in_use.each do |module_usage|
      latest = latest_releases[module_usage.module]
      if module_usage.version != latest
        module_usage.latest = latest
        out_of_date_list << module_usage.to_h
      end
    end
  
    puts out_of_date_list
  end

##################################################

modules=out_of_date_modules()
binding.pry
if modules.size > 1
  namespace_list = namespaces.map { |n| "  * #{n}" }.join("\n")

  message = <<~EOF
    This PR affects multiple namespaces
     #{namespace_list}
     Please submit a separate PR for each namespace.

  EOF

  gh.reject_pr(message)
  exit 1
end
