import argparse
import os
import re
import sys


def save_stats(stats_dict, path):
    """

    :param stats_dict: Stats dict
    :type stats_dict: dict
    :param path: Directory
    :type path: str
    :return:
    """
    for key in stats_dict:
        directory = path + '/' + key.replace(' ', '-').replace('/', '').lower()
        if type(stats_dict[key]) == dict:
            if not os.path.exists(directory):
                os.makedirs(directory)
            save_stats(stats_dict=stats_dict[key], path=directory)
        else:
            f = open(directory, 'w')
            f.write(str(stats_dict[key]))
            f.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='BIND stats file parser')
    parser.add_argument('-f', '--file', dest='file_path', metavar='IN-PATH', default=None)
    parser.add_argument('-p', '--path', dest='path', metavar='OUT-PATH', default='/tmp/named-stats')
    args = parser.parse_args()

    if args.file_path:
        in_string = open(args.file_path).readlines()
    else:
        in_string = sys.stdin.readlines()

    section_regexp = re.compile('^\+\+ (?P<name>.+) \+\+$')
    value_regexp = re.compile('^(?P<value>\d+) (?P<name>.*)$')
    section = None
    stats = {}
    for line in in_string:
        m = section_regexp.match(line.strip())
        if m:
            section = m.groupdict()['name']
            stats[section] = {}
        else:
            m = value_regexp.match(line.strip())
            if m and section:
                stats[section][m.groupdict()['name']] = int(m.groupdict()['value'])

    save_stats(stats_dict=stats, path=args.path)