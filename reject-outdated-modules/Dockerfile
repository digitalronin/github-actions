FROM ministryofjustice/cloud-platform-tools:1.4

# Octokit depends on faraday, and an update to
# faraday breaks the current version of octokit
RUN gem install faraday --version 0.9
RUN gem install octokit

COPY reject-outdated-modules.rb /reject-outdated-modules.rb
COPY github.rb /github.rb

RUN chmod +x /reject-outdated-modules.rb

ENTRYPOINT ["/reject-outdated-modules.rb"]
