from setuptools import setup

setup(
     name='pandoc-inline-headers',
     version='1.0.0',
     scripts=['crossref-ordered-list', 'pandoc-inline-headers'] ,
     author="Alberto Pianon",
     author_email="pianon@array.eu",
     license="GPLv3",
     platforms=['any'],
     description="Pandoc filter to render headers as inline headers in html docx and odt conversion",
     long_description=open("README.rst").read(),
     long_description_content_type="text/x-rst",
     url="https://github.com/alpianon/pandoc-inline-headers",
     classifiers=[
         "Programming Language :: Python :: 3",
         "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
         "Operating System :: OS Independent",
     ],
     install_requires=['panflute',],
 )
