from setuptools import setup

setup(
    name='camera-cli',
    version='0.1',
    py_modules=['camera'],
    install_requires=[
        'argparse',
    ],
    entry_points={
        'console_scripts': [
            'camera=camera:main',
        ],
    },
)