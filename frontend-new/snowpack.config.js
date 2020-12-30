module.exports = {
  extends: '@snowpack/app-scripts-react',
  plugins: [
    [
      '@snowpack/plugin-run-script',
      {
        cmd: 'bsb -make-world',
        watch: '$1 -w',
      },
    ],
  ],
  "experiments": {
    "optimize": {
      "bundle": true,
      "minify": true,
      "target": 'es2018'
    }
  }
};
