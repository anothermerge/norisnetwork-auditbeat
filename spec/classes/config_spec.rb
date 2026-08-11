require 'spec_helper'

describe 'auditbeat', 'type' => 'class' do
  let(:params) do
    { 'outputs' => { 'elasticsearch' => { 'hosts' => ['http://localhost:9200'] } } }
  end

  base_facts = {
    'os' => {
      'family' => 'Debian',
      'name' => 'Ubuntu',
      'release' => { 'full' => '26.04', 'major' => '26.04' },
    },
    'osfamily' => 'Debian',
    'networking' => { 'hostname' => 'testhost' },
  }

  context 'on a node where auditbeat is not installed yet' do
    let(:facts) { base_facts.merge('auditbeat_version' => nil) }

    it 'still renders the configuration' do
      is_expected.to contain_file('/etc/auditbeat/auditbeat.yml').with_content(
        %r{hosts:\s*\n\s*- http://localhost:9200},
      )
    end
  end

  context 'on a node with auditbeat already installed' do
    let(:facts) { base_facts.merge('auditbeat_version' => '9.0.0') }

    it 'renders the configuration' do
      is_expected.to contain_file('/etc/auditbeat/auditbeat.yml').with_content(
        %r{hosts:\s*\n\s*- http://localhost:9200},
      )
    end
  end
end
