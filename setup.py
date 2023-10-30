from setuptools import setup, find_packages
from fmc.version import version

setup(
    name='fmc',
    version=version,
    packages=find_packages(),
    entry_points='''
        [console_scripts]
        fmc=fmc.cli:cli
    ''',
)
