#!/bin/bash

# Install the notebook package
pip install notebook

# Enable Jupyter Widgets Extension
jupyter nbextension enable --py widgetsnbextension --sys-prefix
jupyter nbextension install --py widgetsnbextension --sys-prefix

echo "Jupyter and ipywidgets have been updated. Please restart your Jupyter notebook server."