import React from 'react';
import moment from 'moment';

import Tile from './tile';

export default class WeatherTile extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      latlong: '',
      manualEntry: false,
      error: false
    };
  }

  // geolocation and manual input functions
  locationSubmit() {
    navigator.geolocation.getCurrentPosition((res) => {
      const latlng = `${res.coords.latitude},${res.coords.longitude}`;
      this.setState({
        latlng
      }, (err) => {
        console.log(err);
      }, { maximumAge: Infinity, timeout: 10000 });
      this.props.api.weather(latlng);
      this.setState({ manualEntry: !this.state.manualEntry });
    });
  }

  manualLocationSubmit() {
    event.preventDefault();
    const gpsInput = document.getElementById('gps');
    const latlngNoSpace = gpsInput.value.replace(/\s+/g, '');
    const latlngParse = /-?[0-9]+(?:\.[0-9]*)?,-?[0-9]+(?:\.[0-9]*)?/g;
    if (latlngParse.test(latlngNoSpace)) {
      const latlng = latlngNoSpace;
      this.setState({ latlng }, (err) => {
      console.log(err);
      }, { maximumAge: Infinity, timeout: 10000 });
      this.props.api.launch.weather(latlng);
      this.setState({ manualEntry: !this.state.manualEntry });
    } else {
      this.setState({ error: true });
      return false;
    }
  }
  // set appearance based on weather
  setColors(data) {
    let weatherStyle = {
      gradient1: '',
      gradient2: '',
      text: ''
    };

    switch (data.daily.icon) {
      case 'clear-day':
        weatherStyle = {
          gradient1: '#A5CEF0', gradient2: '#FEF4E0', text: 'black'
        };
        break;
      case 'clear-night':
        weatherStyle = {
          gradient1: '#56668e', gradient2: '#000080', text: 'white'
        };
        break;
      case 'rain':
        weatherStyle = {
          gradient1: '#b1b2b3', gradient2: '#b0c7ff', text: 'black'
        };
        break;
      case 'snow':
        weatherStyle = {
          gradient1: '#eee', gradient2: '#f9f9f9', text: 'black'
        };
        break;
      case 'sleet':
        weatherStyle = {
          gradient1: '#eee', gradient2: '#f9f9f9', text: 'black'
        };
        break;
      case 'wind':
        weatherStyle = {
          gradient1: '#eee', gradient2: '#fff', text: 'black'
        };
        break;
      case 'fog':
        weatherStyle = {
          gradient1: '#eee', gradient2: '#fff', text: 'black'
        };
        break;
      case 'cloudy':
        weatherStyle = {
          gradient1: '#eee', gradient2: '#b1b2b3', text: 'black'
        };
        break;
      case 'partly-cloudy-day':
        weatherStyle = {
          gradient1: '#fcc440', gradient2: '#b1b2b3', text: 'black'
        };
        break;
      case 'partly-cloudy-night':
        weatherStyle = {
          gradient1: '#7f7f7f', gradient2: '#56668e', text: 'white'
        };
        break;
      default:
        weatherStyle = {
          gradient1: 'white', gradient2: 'white', text: 'black'
        };
    }
    return weatherStyle;
  }
  // all tile views
  renderWrapper(child,
    weatherStyle = { gradient1: 'white', gradient2: 'white', text: 'black' }
    ) {
    return (
      <Tile>
      <div
        className={'relative ' + weatherStyle.text}
        style={{
          width: 126,
          height: 126,
          background: `linear-gradient(135deg, ${weatherStyle.gradient1} 0%,` +
          `${weatherStyle.gradient2} 45%, ${weatherStyle.gradient2} 65%,` +
          `${weatherStyle.gradient1} 100%)`
        }}
      >
        {child}
      </div>
      </Tile>
    );
  }

  renderManualEntry() {
    let secureCheck;
    let error;
    if (this.state.error === true) {
      error = <p
          className="f9 red2 pt1"
              >Please try again.
        </p>;
    }
    if (location.protocol === 'https:') {
      secureCheck = (
        <a className="black white-d f9 absolute pointer"
           style={{ right: 8, top: 8 }}
           onClick={() => this.locationSubmit()}>
          Detect ->
        </a>
      );
    }
    return this.renderWrapper(
      <div className={'pa2 w-100 h-100 bg-white bg-gray0-d black white-d ' +
      'b--black b--gray1-d ba'}
      >
        <a
          className="f9 black white-d pointer absolute"
          style={{ top: 8 }}
          onClick={() =>
            this.setState({ manualEntry: !this.state.manualEntry })
          }
        >
          &lt;&#45;
        </a>
        {secureCheck}
        <p className="f9 pt5">
          Please enter your{' '}
          <a
            className="black bb white-d"
            href="https://latitudeandlongitude.org/"
            target="_blank"
          >
            latitude and longitude
          </a>
          .
        </p>
        {error}
        <div className="absolute" style={{ left: 8, bottom: 8 }}>
          <form className="flex" style={{ marginBlockEnd: 0 }}>
            <input
              id="gps"
              className="w-100 black white-d bg-transparent bn f9"
              type="text"
              placeholder="29.558107, -95.089023"
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  this.manualLocationSubmit(e.target.value);
                }
              }} />
            <input
              className={'bg-transparent black white-d bn pointer ' +
              'f9 flex-shrink-0 pr1'}
              type="submit"
              onClick={() => this.manualLocationSubmit()}
              value="->"
            />
          </form>
        </div>
      </div>
    );
  }

  renderNoData() {
    return this.renderWrapper((
      <div
        className={'pa2 w-100 h-100 b--black b--gray1-d ba ' +
        'bg-white bg-gray0-d black white-d'}
      onClick={() => this.setState({ manualEntry: !this.state.manualEntry })}
      >
          <p className="f9 absolute"
            style={{ left: 8, top: 8 }}
          >
            Weather
          </p>
        <p className="absolute w-100 flex-col f9"
        style={{ bottom: 8, left: 8, cursor: 'pointer' }}
        >
        -> Set location
        </p>
      </div>
    ));
  }

  renderWithData(data, weatherStyle) {
    const c = data.currently;
    const d = data.daily.data[0];

    const da = moment.unix(d.sunsetTime).format('h:mm a') || '';

    return this.renderWrapper(
      <div className="w-100 h-100 b--black b--gray1-d ba"
      style={{ backdropFilter: 'blur(80px)' }}
      >
        <p className="f9 absolute" style={{ left: 8, top: 8 }}>
          Weather
        </p>
        <a
          className="f9 absolute pointer"
          style={{ right: 8, top: 8 }}
          onClick={() =>
            this.setState({ manualEntry: !this.state.manualEntry })
          }
        >
          ->
        </a>
        <div className="w-100 absolute" style={{ left: 8, bottom: 8 }}>
          <p className="f9">{c.summary}</p>
          <p className="f9 pt1">{Math.round(c.temperature)}°</p>
          <p className="f9 pt1">Sunset at {da}</p>
        </div>
      </div>
    , weatherStyle);
  }

  render() {
    const data = this.props.weather ? this.props.weather : {};

    if (this.state.manualEntry === true) {
      return this.renderManualEntry();
    }

    if ('currently' in data && 'daily' in data) {
      const weatherStyle = this.setColors(data);
      return this.renderWithData(data, weatherStyle);
    }

    if (this.props.location) {
      return this.renderWrapper((
        <div
          className={'pa2 w-100 h-100 b--black b--gray1-d ba ' +
          'bg-white bg-gray0-d black white-d'}>
            <p className="f9 absolute"
              style={{ left: 8, top: 8 }}
            >
              Weather
            </p>
          <p className="absolute w-100 flex-col f9"
          style={{ bottom: 8, left: 8 }}
          >
          Loading, please check again later...
          </p>
        </div>
      ));
    }
    return this.renderNoData();
  }
}

