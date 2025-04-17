title "Ansible Baseline"
# All systems, which are installed and configured through Ansible, should comply to the same basic ruleset.

control 'packages-01' do
  impact 1.0
  title 'Check for essential tools'
  desc 'Ensure essential tools are installed'

  binaries = [
    '/usr/bin/ansible',
    '/usr/bin/asciidoctor',
    '/usr/bin/balena-etcher',
    '/usr/bin/curl',
    '/usr/bin/docker',
    '/usr/bin/filezilla',
    '/usr/bin/gh',
    '/usr/bin/git',
    '/usr/bin/htop',
    '/usr/bin/jq',
    '/usr/bin/make',
    '/usr/bin/ncdu',
    '/usr/bin/neofetch',
    '/usr/bin/nmap',
    '/usr/bin/rpi-imager',
    '/usr/bin/task',
    '/usr/bin/tilix',
    '/usr/bin/vagrant',
    '/usr/bin/virtualbox',
    '/usr/bin/vim',
    '/usr/bin/yarn',
    '/usr/bin/rar',
    '/usr/bin/unrar',
    '/usr/bin/p7zip',
    '/usr/local/bin/pre-commit',
    '/snap/bin/postman',
    '/snap/bin/spotify',
    # '~/.atuin/bin/atuin',
    # TODO intellij
    # TODO vscode
    # TODO sublime
  ]

  binaries.each do |binary|
    describe file(binary) do
      it { should exist }
      it { should be_executable }
    end
  end
end
