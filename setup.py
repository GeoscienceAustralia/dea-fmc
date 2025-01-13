from setuptools import setup

if __name__ == "__main__":
    setup(
        # setuptools_scm
        use_scm_version=True,
        setup_requires=["setuptools_scm"],
        # package metadata
        name="dea-fmc",
        packages=["dea_fmc"],
        python_requires=">=3.8",
        entry_points={
            "console_scripts": ["dea-fmc=dea_fmc.__main__:main"],
        },
    )
