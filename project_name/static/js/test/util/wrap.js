import React from 'react';

export default function wrap (Component) {
  /**
   * Function to wrap a stateless functional React component in order to make
   * the imperative API for React components available (for testing etc).
   *
   * @function wrap
   * @param {function} Component - the stateless functional component to wrap
   * @returns {React.Component}
   */
  return class extends React.Component {
    render () {
      return Component(this.props);
    }
  }
}
