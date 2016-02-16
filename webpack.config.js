var webpack = require('webpack');
var path = require('path');

module.exports = {
  devtool: 'source-map',
  debug: false,
  entry: {
    'app': './app/boot.ts',
    'vendor': './app/vendor.ts'
  },
  output: {
    path: "./build",
    publicPath: "/build/",
    filename: "bundle.js"
  },
  plugins: [
    new webpack.optimize.CommonsChunkPlugin('vendor', 'vendor.js')
  ],

  resolve: {
    extensions: ['', '.ts', '.js', '.html', '.css']
  },

  module: {
    loaders: [
      { test: /\.ts$/, loader: 'ts-loader' },
      { test: /\.html?$/, loader: 'raw-loader'},
      { test: /\.css?$/, loader: 'raw-loader'}
    ],
    //noParse: [ path.join(__dirname, 'node_modules', 'angular2', 'bundles') ]
  },

  devServer: {
    historyApiFallback: true
  }
};
