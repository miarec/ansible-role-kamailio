import os
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')

def test_directories(host):
    dirs = [
        "/var/log/kamailio",
        "/opt/kamailio",
    ]

    for dir in dirs:
        d = host.file(dir)
        assert d.is_directory
        assert d.exists

def test_files(host):

    files = [
        "/var/log/kamailio/kamailio.log",
    ]

    for file in files:
        f = host.file(file)
        assert f.exists
        assert f.is_file

def test_service(host):
    s = host.service("kamailio")

    assert s.is_enabled
    assert s.is_running


def test_socket(host):
    sockets = [
        "udp://0.0.0.0:5060",
        "tcp://0.0.0.0:5060",
    ]
    for socket in sockets:
        s = host.socket(socket)
        assert s.is_listening
