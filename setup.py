from setuptools import setup, find_packages

setup(
    name='fmc',
    version='0.1',
    packages=find_packages(),
    entry_points='''
        [console_scripts]
        fmc=fmc.cli:cli
    ''',
)
