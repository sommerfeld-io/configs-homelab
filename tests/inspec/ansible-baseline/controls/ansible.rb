title "Ansible Baseline"
# All systems, which are installed and configured through Ansible, should comply to the same basic ruleset.

control 'ansible-01' do
  impact 1.0
  title 'Check for essential tools'
  desc 'Ensure essential tools are installed'

  describe file('/usr/bin/curl') do
    it { should exist }
    it { should be_executable }
  end
end
