const manifest = {"name":"N.E.C.A"};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
let api;
try {
    api = internalAPIConnection.connect(API_VERSION, manifest.name);
}
catch {
    api = internalAPIConnection.connect(1, manifest.name);
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version 1. Some features may not work.`);
}
if (api._version != API_VERSION) {
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version ${api._version}. Some features may not work.`);
}
const call = api.call;
const definePlugin = (fn) => {
    return (...args) => {
        return fn(...args);
    };
};

var DefaultContext = {
  color: undefined,
  size: undefined,
  className: undefined,
  style: undefined,
  attr: undefined
};
var IconContext = SP_REACT.createContext && /*#__PURE__*/SP_REACT.createContext(DefaultContext);

var _excluded = ["attr", "size", "title"];
function _objectWithoutProperties(e, t) { if (null == e) return {}; var o, r, i = _objectWithoutPropertiesLoose(e, t); if (Object.getOwnPropertySymbols) { var n = Object.getOwnPropertySymbols(e); for (r = 0; r < n.length; r++) o = n[r], -1 === t.indexOf(o) && {}.propertyIsEnumerable.call(e, o) && (i[o] = e[o]); } return i; }
function _objectWithoutPropertiesLoose(r, e) { if (null == r) return {}; var t = {}; for (var n in r) if ({}.hasOwnProperty.call(r, n)) { if (-1 !== e.indexOf(n)) continue; t[n] = r[n]; } return t; }
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == typeof i ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != typeof t || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != typeof i) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function Tree2Element(tree) {
  return tree && tree.map((node, i) => /*#__PURE__*/SP_REACT.createElement(node.tag, _objectSpread({
    key: i
  }, node.attr), Tree2Element(node.child)));
}
function GenIcon(data) {
  return props => /*#__PURE__*/SP_REACT.createElement(IconBase, _extends({
    attr: _objectSpread({}, data.attr)
  }, props), Tree2Element(data.child));
}
function IconBase(props) {
  var elem = conf => {
    var attr = props.attr,
      size = props.size,
      title = props.title,
      svgProps = _objectWithoutProperties(props, _excluded);
    var computedSize = size || conf.size || "1em";
    var className;
    if (conf.className) className = conf.className;
    if (props.className) className = (className ? className + " " : "") + props.className;
    return /*#__PURE__*/SP_REACT.createElement("svg", _extends({
      stroke: "currentColor",
      fill: "currentColor",
      strokeWidth: "0"
    }, conf.attr, attr, svgProps, {
      className: className,
      style: _objectSpread(_objectSpread({
        color: props.color || conf.color
      }, conf.style), props.style),
      height: computedSize,
      width: computedSize,
      xmlns: "http://www.w3.org/2000/svg"
    }), title && /*#__PURE__*/SP_REACT.createElement("title", null, title), props.children);
  };
  return IconContext !== undefined ? /*#__PURE__*/SP_REACT.createElement(IconContext.Consumer, null, conf => elem(conf)) : elem(DefaultContext);
}

// THIS FILE IS AUTO GENERATED
function SiSteamdeck (props) {
  return GenIcon({"attr":{"role":"img","viewBox":"0 0 24 24"},"child":[{"tag":"path","attr":{"d":"M8.999 0v4.309c4.242 0 7.694 3.45 7.694 7.691s-3.452 7.691-7.694 7.691V24c6.617 0 12-5.383 12-12s-5.383-12-12-12Zm0 6.011c-3.313 0-6 2.687-5.998 6a5.999 5.999 0 1 0 5.998-6z"},"child":[]}]})(props);
}function SiMsi (props) {
  return GenIcon({"attr":{"role":"img","viewBox":"0 0 24 24"},"child":[{"tag":"path","attr":{"d":"M16.362 10.042c-1.044.56-2.193 1.05-3.7 1.142a4.26 4.26 0 0 1-2.321-.556c-.155-.09-.51-.26-.503-.457.011-.242.582-.303.816-.306 5.262-.178 6.29-2.472 6.286-2.563 0-.083-.09.011-.09.011-1.38 1.777-4.937 1.973-4.937 1.973-.877.121-1.761-.08-2.215-.529a.794.794 0 0 1-.215-.39c-.102.122-.17.25-.291.379-.114.128-.458.499-.484.06-.019-.325.076-.393.2-.586a5.178 5.178 0 0 1 .193-.276c.374-.49.684-.997 1.123-1.402.037-.038.11-.075.09-.11a6.221 6.221 0 0 0-3.624 4.166 6.508 6.508 0 0 0-.23 1.72c0 .62.082 1.209.21 1.75.258 1.073.56 1.817 1.033 2.66.155-.211.219-.491.306-.752.098-.276.166-.642.302-.87.321-.528 2.079-.396 1.599-.763a3.613 3.613 0 0 1-.397-.359 7.083 7.083 0 0 1-.673-.831c-.412-.582-.756-1.285-.79-2.2.469 1.21 1.18 2.222 2.313 2.774.378.182.813.378 1.323.367-1.341-.253-2.162-1.285-2.717-2.374-.087-.17-.208-.332-.25-.476a.4.4 0 0 1-.011-.189c.076-.336.484-.17.726-.083a8.489 8.489 0 0 0 3.602.438 6.678 6.678 0 0 0 1.874-.476c.545-.227 1.04-.518 1.452-.896m-2.34 2.657a8.001 8.001 0 0 1-2.4-.189 3.969 3.969 0 0 1-1.754-.865c-.181-.166-.295-.469-.597-.397-.026.22.151.378.272.514a3.507 3.507 0 0 0 1.573.896c.835.257 2.003.283 2.906.038M11.35 10.22c-.178 0-.771-.098-.786.098-.012.121.245.212.381.25.53.136 1.255.086 1.784.037a8.515 8.515 0 0 0 2.098-.465c.99-.362 1.795-.88 2.457-1.55.181-.18.162-.234-.034-.067a6.365 6.365 0 0 1-1.769 1.032c-1.172.472-2.517.665-4.131.665m6.576-6.717c.136.034.299.027.37.068.133.08.133.273.224.431-.54.091-.718-.302-.972-.585.091.007.227.052.378.086M7.325 16.57c-.393-.613-2.39-3.19-.832-6.989 2.128-5.178 7.88-3.772 8.421-3.557.064-.434.257-.884.764-.994a1.712 1.712 0 0 1 .612 0c-.522.193-1.077.427-1.05.976.022.49.52.835.936.91 0 0 .33.072.567-.075a.019.019 0 0 0 .016-.012c.064-.037.12-.075.204-.105a.979.979 0 0 1 .529-.023c.049.011.143.09.227.087.052 0 .136-.076.211-.087.2-.038.397.072.582.147.125.053.465.099.488.273.011.12-.178.264-.28.34a1.765 1.765 0 0 1-.423.23c.56-.045 1.682-.48 1.512.246-.015.076-.057.14-.042.178.578-.197.76-.685.673-1.372-.076.022-.14.17-.2.215v-.004c0-.196.01-.491-.125-.612.068.359-.121.53-.382.654a6.176 6.176 0 0 0-.695-.975c-.027.113-.012.26-.046.37a.518.518 0 0 0-.438-.351c-.129-.02-.272.022-.427 0-.2-.034-.431-.174-.446-.325-.027-.25.423-.367.65-.428.049.163.117.295.17.45a1.693 1.693 0 0 1 .964-.43c.102 0 .329.037.363.113.079.162-.129.355-.19.427-.037.038-.098.08-.079.102.39-.102.567-.355.84-.544.143.189.196.59.173.858.31-.303.318-.824.291-1.376a1.761 1.761 0 0 1 .749.597 1.943 1.943 0 0 0-.68-.756c-.1-.064-.228-.094-.303-.166-.068-.068-.151-.303-.242-.322-.113-.022-.265.11-.397.118-.238.019-.367-.144-.416-.378-.578.158-.8-.197-.937-.632-.023-.075-.023-.18-.06-.264-.042-.106-.273-.212-.394-.257a1.092 1.092 0 0 0-.548-.068c-.17.026-.294.113-.491.12-.476.027-.971-.18-1.357-.37A8.289 8.289 0 0 1 12.896.113c-.03-.038-.053-.094-.11-.113.125.385.348.707.556 1.005.639.915 1.47 1.58 2.283 2.215a1.308 1.308 0 0 1-.805-.208 4.165 4.165 0 0 1-.65-.416c-.85.726-2.548.81-3.916 1.134.567-.019 1.417.163 1.916.246h-.015c-2.389.094-4.449.794-5.877 2.147.37-.136.706-.306 1.118-.405-.59.537-1.171 1.096-1.644 1.75-.468.647-.967 1.33-.986 2.404.287-.28.578-.642.979-.847a13.108 13.108 0 0 0-.85 2.268c-.197.718-.492 1.913-.02 2.582.03-.238.03-.51.19-.624.28.661.76 1.996 2.26 3.319m5.68-14.095c.114.102.333.273.465.265.208 0 .314-.189.458-.272-.719-.321-1.388-.786-2.034-1.168.098.151.227.28.355.435.239.272.477.506.756.74m-8.05 5.16c.075.155 0 .366.011.517.234-.635.688-1.134 1.119-1.572.023-.026.087-.08.049-.072-.227.11-.355.314-.665.34-.174-.196-.174-.793.06-.922.288.087.477-.162.446-.427-.056-.423-.578-.707-.816-.877.125.159.367.303.423.537.02.083.015.242-.075.268-.133.038-.208-.11-.34-.09-.114.018-.167.219-.19.359a2.76 2.76 0 0 0-.03.529c0 .087.034.219-.03.283-.08-.038-.098-.136-.132-.215-.125-.276-.34-.647-.254-1.013.057-.023.163.007.2-.03.02-.227-.143-.443-.29-.586a.983.983 0 0 0-.926-.227c.211.038.68.068.684.302 0 .087-.102.212-.129.28-.166.408.023.93.22 1.194.113.152.28.295.181.575-.128-.008-.246-.09-.363-.155-.166-.095-.34-.185-.423-.329-.083-.162-.09-.325-.204-.446-.284-.321-.896-.544-1.342-.272.378-.011.73.011.877.26a1.119 1.119 0 0 1 .12.454c.008.068-.01.16.023.208.057.098.235.083.34.144.14.08.227.298.382.435a1.02 1.02 0 0 0 .133.102c.242.143.816.196.937.446m3.046 10.057c-.578.306-.914.907-.986 1.67.113-.302.43-.46.767-.615.216-.099.601-.197.662-.397.053-.155.037-.405-.038-.507-.083-.113-.227-.147-.405-.15m1.406 2.683a1.708 1.708 0 0 0-.907 1.38c.117-.28.424-.398.734-.53.189-.076.517-.162.578-.317.045-.125.045-.326-.023-.416-.064-.095-.283-.167-.382-.121m1.701 1.625c-.321.287-.506.88-.476 1.444.08-.321.325-.446.605-.631.162-.102.491-.261.552-.42a.469.469 0 0 0-.118-.461c-.181-.151-.453-.026-.567.072m2.627.567c-.313.276-.415.831-.34 1.432.076-.302.238-.45.454-.635.128-.113.332-.264.374-.42.068-.256-.208-.51-.491-.377m.544-6.085c.174.022.34.113.476.158.011-.049-.05-.071-.08-.098-.385-.329-1.277-.196-1.473.208.034.072.155.076.173.162.016.091-.117.223-.185.295-.177.193-.344.303-.544.439-.098.068-.185.181-.302.17.06-.238.189-.333.29-.537.076-.136.25-.499.152-.646-.057-.095-.355-.046-.4-.151-.039-.087.03-.197.079-.25.14-.151.43-.234.687-.287-.393 0-1.103.132-1.27.457-.113.22-.015.53.231.556.095.306-.151.684-.333.824a.344.344 0 0 1-.15.083c-.303.038-.22-.31-.296-.53-.026-.075-.075-.139-.12-.2-.084.783.086 1.554.264 2.17-.019-.215.015-.43.151-.495.31-.151.726.075 1.089.098.378.019.597-.212.858-.22.136 0 .234.092.359.061.087-.022.159-.181.234-.28a1.017 1.017 0 0 1 .265-.256c.359-.208.73.075.967.208-.211-.39-.914-.688-1.451-.428-.113.053-.204.193-.336.265-.205.121-.48.087-.745.076-.09-.008-.189.019-.26-.042.067-.34.392-.351.634-.499.348-.208.68-.525.718-1.02 0-.068-.026-.163.027-.227.049-.068.174-.076.29-.06m3.138 5.204c-.136-.17-.446-.125-.488.087-.038.215.151.438.284.574a1.126 1.126 0 0 0 .514.36c.011 0 .019.018.022 0a1.01 1.01 0 0 1-.215-.477c-.038-.211-.026-.43-.12-.548m.585-9.343c.359.026.847.14.979.348-.087-.284-.631-1.867-3.156-1.758.503.151 1.077.321 1.512.597.132.08.325.204.302.405-.026.223-.446.434-.748.457-.325.023-.575-.128-.764-.227.321.409.847.715 1.591.635-.018-.094-.143-.204-.09-.347.038-.099.2-.125.374-.114m2.086 6.04c-.098.023-.219.163-.208.302.02.19.254.28.465.265a1.175 1.175 0 0 0 .718-.291c-.396.102-.672-.34-.975-.276m.34-.922c.235-.34.31-.896.393-1.414.042-.276.08-.529.16-.733.09-.22.241-.393.294-.616.05-.216-.038-.37-.113-.548-.174-.4-.348-.798-.673-1.002-.386-.245-.987-.177-1.535-.132a18.282 18.282 0 0 0-.767.076 5.216 5.216 0 0 1-.794.064c-1.096-.02-1.727-.548-1.848-1.542 0 0 0-.012-.011-.008-.151.99.408 1.576 1.21 1.75.064.136.21.257.162.446-.053.227-.424.234-.684.2a1.425 1.425 0 0 1-.658-.28 3.383 3.383 0 0 1-.854-1 2.699 2.699 0 0 0 2.721 1.836c.48-.034.919-.14 1.3-.287-.555 0-1.292.019-1.451-.367a.503.503 0 0 1 .06-.438c.47.056.889-.046 1.282-.068a2.744 2.744 0 0 1 .96.117 1.22 1.22 0 0 1 .642.438c.272.4.303.987.204 1.561a7.181 7.181 0 0 1-.453 1.41c-.37.922-1.111 2.317-1.697 2.835-.703.593-1.584.937-2.608 1.202a6.66 6.66 0 0 1-1.323.208c-1.054.045-1.901-.102-2.46-.598a2.445 2.445 0 0 1-.605-.914 6.474 6.474 0 0 1-.363-3.04c-.038-.007-.064.035-.083.046-.03.03-.057.065-.09.091-.371.333-1.146.813-1.834.488a.635.635 0 0 1-.314-.288c-.189-.363.095-.676.314-.846.162-.125.382-.284.654-.216.162.038.416.246.416.416 0 .098-.223.28-.394.28-.177 0-.29-.144-.377-.227-.016-.027-.046-.087-.087-.06-.19.83.986.8 1.39.404.348-.34.48-1.062.163-1.52-.189-.264-.54-.366-.93-.31-.347.053-.812.152-1.028.314-.302.235-.34.726-.46 1.111a3.651 3.651 0 0 1-.454.972c-.027.038-.072.064-.065.11.465.03.862.15 1.002.487a.907.907 0 0 1 .038.465c-.065.302-.238.555-.102.915.226.597 1.092.71 1.36 1.254.114.223.091.537.235.756.177.269.597.238.986.303.22.045.439.09.605.192.321.19.332.632.718.768.23.075.43-.038.624-.091.15-.042.31-.064.453-.09.337-.054.582.026.9.12a1.406 1.406 0 0 0 .895 0c.257-.098.443-.276.643-.438.408-.325.809-.631 1.353-.805.552-.174 1.21-.261 1.512-.643a2.124 2.124 0 0 0 .302-.839c.14-.631.344-1.202.639-1.652.151-.226.37-.4.525-.623m1.24-4.12c-.087.117-.28.132-.408.212-.027.46.476-.02.408-.216m.19 2.192c-.186.121-.553-.064-.711.095-.084.605.653.159.729-.068 0-.015 0-.03-.023-.027"},"child":[]}]})(props);
}function SiLenovo (props) {
  return GenIcon({"attr":{"role":"img","viewBox":"0 0 24 24"},"child":[{"tag":"path","attr":{"d":"M21.044 12.288c0 .5-.343.867-.815.867-.464 0-.827-.38-.827-.867 0-.51.343-.868.815-.868.464 0 .827.381.827.868zm-14.305-.92a.787.787 0 0 0-.651.307.991.991 0 0 0-.172.738l1.479-.614a.708.708 0 0 0-.656-.43zm6.963.052c-.472 0-.816.358-.816.868 0 .486.364.867.828.867.472 0 .815-.368.815-.867 0-.487-.363-.868-.827-.868zM24 7.997v8.006H0V7.997h24zM5.01 13.05H3.088V9.825H2.23v4.003h2.78v-.777zm1.137-.094l2.163-.897a1.667 1.667 0 0 0-.37-.86c-.284-.33-.704-.505-1.216-.505-.931 0-1.633.686-1.633 1.593 0 .93.704 1.593 1.726 1.593.572 0 1.158-.272 1.432-.589l-.535-.411c-.357.264-.56.326-.885.326-.292 0-.52-.09-.682-.25zm5.57-1.039c0-.709-.507-1.223-1.252-1.223a1.28 1.28 0 0 0-1.005.494v-.442h-.846v3.081h.846v-1.753c0-.316.245-.651.698-.651.35 0 .712.243.712.651v1.753h.847v-1.91zm3.647.37c0-.904-.725-1.593-1.65-1.593-.933 0-1.663.7-1.663 1.593 0 .903.726 1.592 1.651 1.592.932 0 1.662-.7 1.662-1.592zm2.066 1.54l1.268-3.081h-.967l-.765 2.099-.765-2.1h-.966l1.268 3.081h.927zm4.449-1.54c0-.904-.725-1.593-1.65-1.593-.932 0-1.662.7-1.662 1.593 0 .903.725 1.592 1.65 1.592.932 0 1.662-.7 1.662-1.592z"},"child":[]}]})(props);
}function SiAsus (props) {
  return GenIcon({"attr":{"role":"img","viewBox":"0 0 24 24"},"child":[{"tag":"path","attr":{"d":"M23.904 10.788V9.522h-4.656c-.972 0-1.41.6-1.482 1.182v.018-1.2h-1.368v1.266h1.362zm-6.144.456l-1.368-.078v1.458c0 .456-.228.594-1.02.594H14.28c-.654 0-.93-.186-.93-.594v-1.596l-1.386-.102v1.812h-.03c-.078-.528-.276-1.14-1.596-1.23L6 11.22c0 .666.474 1.062 1.218 1.14l3.024.306c.24.018.414.09.414.288 0 .216-.18.24-.456.24H5.946V11.22l-1.386-.09v3.348h5.646c1.26 0 1.662-.654 1.722-1.2h.03c.156.864.912 1.2 2.19 1.2h1.41c1.494 0 2.202-.456 2.202-1.524zm4.398.258l-4.338-.258c0 .666.438 1.11 1.182 1.17l3.09.24c.24.018.384.078.384.276 0 .186-.168.258-.516.258h-4.212v1.29h4.302c1.356 0 1.95-.474 1.95-1.554 0-.972-.534-1.338-1.842-1.422zm-10.194-1.98h1.386v1.266h-1.386zM3.798 11.07l-1.506-.15L0 14.478h1.686zm7.914-1.548h-4.23c-.984 0-1.416.612-1.518 1.2v-1.2H3.618c-.33 0-.486.102-.642.33l-.648.936h9.384Z"},"child":[]}]})(props);
}

// THIS FILE IS AUTO GENERATED
function FaXbox (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M369.9 318.2c44.3 54.3 64.7 98.8 54.4 118.7-7.9 15.1-56.7 44.6-92.6 55.9-29.6 9.3-68.4 13.3-100.4 10.2-38.2-3.7-76.9-17.4-110.1-39C93.3 445.8 87 438.3 87 423.4c0-29.9 32.9-82.3 89.2-142.1 32-33.9 76.5-73.7 81.4-72.6 9.4 2.1 84.3 75.1 112.3 109.5zM188.6 143.8c-29.7-26.9-58.1-53.9-86.4-63.4-15.2-5.1-16.3-4.8-28.7 8.1-29.2 30.4-53.5 79.7-60.3 122.4-5.4 34.2-6.1 43.8-4.2 60.5 5.6 50.5 17.3 85.4 40.5 120.9 9.5 14.6 12.1 17.3 9.3 9.9-4.2-11-.3-37.5 9.5-64 14.3-39 53.9-112.9 120.3-194.4zm311.6 63.5C483.3 127.3 432.7 77 425.6 77c-7.3 0-24.2 6.5-36 13.9-23.3 14.5-41 31.4-64.3 52.8C367.7 197 427.5 283.1 448.2 346c6.8 20.7 9.7 41.1 7.4 52.3-1.7 8.5-1.7 8.5 1.4 4.6 6.1-7.7 19.9-31.3 25.4-43.5 7.4-16.2 15-40.2 18.6-58.7 4.3-22.5 3.9-70.8-.8-93.4zM141.3 43C189 40.5 251 77.5 255.6 78.4c.7.1 10.4-4.2 21.6-9.7 63.9-31.1 94-25.8 107.4-25.2-63.9-39.3-152.7-50-233.9-11.7-23.4 11.1-24 11.9-9.4 11.2z"},"child":[]}]})(props);
}function FaUsb (props) {
  return GenIcon({"attr":{"viewBox":"0 0 640 512"},"child":[{"tag":"path","attr":{"d":"M641.5 256c0 3.1-1.7 6.1-4.5 7.5L547.9 317c-1.4.8-2.8 1.4-4.5 1.4-1.4 0-3.1-.3-4.5-1.1-2.8-1.7-4.5-4.5-4.5-7.8v-35.6H295.7c25.3 39.6 40.5 106.9 69.6 106.9H392V354c0-5 3.9-8.9 8.9-8.9H490c5 0 8.9 3.9 8.9 8.9v89.1c0 5-3.9 8.9-8.9 8.9h-89.1c-5 0-8.9-3.9-8.9-8.9v-26.7h-26.7c-75.4 0-81.1-142.5-124.7-142.5H140.3c-8.1 30.6-35.9 53.5-69 53.5C32 327.3 0 295.3 0 256s32-71.3 71.3-71.3c33.1 0 61 22.8 69 53.5 39.1 0 43.9 9.5 74.6-60.4C255 88.7 273 95.7 323.8 95.7c7.5-20.9 27-35.6 50.4-35.6 29.5 0 53.5 23.9 53.5 53.5s-23.9 53.5-53.5 53.5c-23.4 0-42.9-14.8-50.4-35.6H294c-29.1 0-44.3 67.4-69.6 106.9h310.1v-35.6c0-3.3 1.7-6.1 4.5-7.8 2.8-1.7 6.4-1.4 8.9.3l89.1 53.5c2.8 1.1 4.5 4.1 4.5 7.2z"},"child":[]}]})(props);
}function FaSteam (props) {
  return GenIcon({"attr":{"viewBox":"0 0 496 512"},"child":[{"tag":"path","attr":{"d":"M496 256c0 137-111.2 248-248.4 248-113.8 0-209.6-76.3-239-180.4l95.2 39.3c6.4 32.1 34.9 56.4 68.9 56.4 39.2 0 71.9-32.4 70.2-73.5l84.5-60.2c52.1 1.3 95.8-40.9 95.8-93.5 0-51.6-42-93.5-93.7-93.5s-93.7 42-93.7 93.5v1.2L176.6 279c-15.5-.9-30.7 3.4-43.5 12.1L0 236.1C10.2 108.4 117.1 8 247.6 8 384.8 8 496 119 496 256zM155.7 384.3l-30.5-12.6a52.79 52.79 0 0 0 27.2 25.8c26.9 11.2 57.8-1.6 69-28.4 5.4-13 5.5-27.3.1-40.3-5.4-13-15.5-23.2-28.5-28.6-12.9-5.4-26.7-5.2-38.9-.6l31.5 13c19.8 8.2 29.2 30.9 20.9 50.7-8.3 19.9-31 29.2-50.8 21zm173.8-129.9c-34.4 0-62.4-28-62.4-62.3s28-62.3 62.4-62.3 62.4 28 62.4 62.3-27.9 62.3-62.4 62.3zm.1-15.6c25.9 0 46.9-21 46.9-46.8 0-25.9-21-46.8-46.9-46.8s-46.9 21-46.9 46.8c.1 25.8 21.1 46.8 46.9 46.8z"},"child":[]}]})(props);
}function FaPlaystation (props) {
  return GenIcon({"attr":{"viewBox":"0 0 576 512"},"child":[{"tag":"path","attr":{"d":"M570.9 372.3c-11.3 14.2-38.8 24.3-38.8 24.3L327 470.2v-54.3l150.9-53.8c17.1-6.1 19.8-14.8 5.8-19.4-13.9-4.6-39.1-3.3-56.2 2.9L327 381.1v-56.4c23.2-7.8 47.1-13.6 75.7-16.8 40.9-4.5 90.9.6 130.2 15.5 44.2 14 49.2 34.7 38 48.9zm-224.4-92.5v-139c0-16.3-3-31.3-18.3-35.6-11.7-3.8-19 7.1-19 23.4v347.9l-93.8-29.8V32c39.9 7.4 98 24.9 129.2 35.4C424.1 94.7 451 128.7 451 205.2c0 74.5-46 102.8-104.5 74.6zM43.2 410.2c-45.4-12.8-53-39.5-32.3-54.8 19.1-14.2 51.7-24.9 51.7-24.9l134.5-47.8v54.5l-96.8 34.6c-17.1 6.1-19.7 14.8-5.8 19.4 13.9 4.6 39.1 3.3 56.2-2.9l46.4-16.9v48.8c-51.6 9.3-101.4 7.3-153.9-10z"},"child":[]}]})(props);
}function FaBluetoothB (props) {
  return GenIcon({"attr":{"viewBox":"0 0 320 512"},"child":[{"tag":"path","attr":{"d":"M196.48 260.023l92.626-103.333L143.125 0v206.33l-86.111-86.111-31.406 31.405 108.061 108.399L25.608 368.422l31.406 31.405 86.111-86.111L145.84 512l148.552-148.644-97.912-103.333zm40.86-102.996l-49.977 49.978-.338-100.295 50.315 50.317zM187.363 313.04l49.977 49.978-50.315 50.316.338-100.294z"},"child":[]}]})(props);
}function FaUndo (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M212.333 224.333H12c-6.627 0-12-5.373-12-12V12C0 5.373 5.373 0 12 0h48c6.627 0 12 5.373 12 12v78.112C117.773 39.279 184.26 7.47 258.175 8.007c136.906.994 246.448 111.623 246.157 248.532C504.041 393.258 393.12 504 256.333 504c-64.089 0-122.496-24.313-166.51-64.215-5.099-4.622-5.334-12.554-.467-17.42l33.967-33.967c4.474-4.474 11.662-4.717 16.401-.525C170.76 415.336 211.58 432 256.333 432c97.268 0 176-78.716 176-176 0-97.267-78.716-176-176-176-58.496 0-110.28 28.476-142.274 72.333h98.274c6.627 0 12 5.373 12 12v48c0 6.627-5.373 12-12 12z"},"child":[]}]})(props);
}function FaSyncAlt (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M370.72 133.28C339.458 104.008 298.888 87.962 255.848 88c-77.458.068-144.328 53.178-162.791 126.85-1.344 5.363-6.122 9.15-11.651 9.15H24.103c-7.498 0-13.194-6.807-11.807-14.176C33.933 94.924 134.813 8 256 8c66.448 0 126.791 26.136 171.315 68.685L463.03 40.97C478.149 25.851 504 36.559 504 57.941V192c0 13.255-10.745 24-24 24H345.941c-21.382 0-32.09-25.851-16.971-40.971l41.75-41.749zM32 296h134.059c21.382 0 32.09 25.851 16.971 40.971l-41.75 41.75c31.262 29.273 71.835 45.319 114.876 45.28 77.418-.07 144.315-53.144 162.787-126.849 1.344-5.363 6.122-9.15 11.651-9.15h57.304c7.498 0 13.194 6.807 11.807 14.176C478.067 417.076 377.187 504 256 504c-66.448 0-126.791-26.136-171.315-68.685L48.97 471.03C33.851 486.149 8 475.441 8 454.059V320c0-13.255 10.745-24 24-24z"},"child":[]}]})(props);
}function FaStar (props) {
  return GenIcon({"attr":{"viewBox":"0 0 576 512"},"child":[{"tag":"path","attr":{"d":"M259.3 17.8L194 150.2 47.9 171.5c-26.2 3.8-36.7 36.1-17.7 54.6l105.7 103-25 145.5c-4.5 26.3 23.2 46 46.4 33.7L288 439.6l130.7 68.7c23.2 12.2 50.9-7.4 46.4-33.7l-25-145.5 105.7-103c19-18.5 8.5-50.8-17.7-54.6L382 150.2 316.7 17.8c-11.7-23.6-45.6-23.9-57.4 0z"},"child":[]}]})(props);
}function FaSlidersH (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M496 384H160v-16c0-8.8-7.2-16-16-16h-32c-8.8 0-16 7.2-16 16v16H16c-8.8 0-16 7.2-16 16v32c0 8.8 7.2 16 16 16h80v16c0 8.8 7.2 16 16 16h32c8.8 0 16-7.2 16-16v-16h336c8.8 0 16-7.2 16-16v-32c0-8.8-7.2-16-16-16zm0-160h-80v-16c0-8.8-7.2-16-16-16h-32c-8.8 0-16 7.2-16 16v16H16c-8.8 0-16 7.2-16 16v32c0 8.8 7.2 16 16 16h336v16c0 8.8 7.2 16 16 16h32c8.8 0 16-7.2 16-16v-16h80c8.8 0 16-7.2 16-16v-32c0-8.8-7.2-16-16-16zm0-160H288V48c0-8.8-7.2-16-16-16h-32c-8.8 0-16 7.2-16 16v16H16C7.2 64 0 71.2 0 80v32c0 8.8 7.2 16 16 16h208v16c0 8.8 7.2 16 16 16h32c8.8 0 16-7.2 16-16v-16h208c8.8 0 16-7.2 16-16V80c0-8.8-7.2-16-16-16z"},"child":[]}]})(props);
}function FaQuestion (props) {
  return GenIcon({"attr":{"viewBox":"0 0 384 512"},"child":[{"tag":"path","attr":{"d":"M202.021 0C122.202 0 70.503 32.703 29.914 91.026c-7.363 10.58-5.093 25.086 5.178 32.874l43.138 32.709c10.373 7.865 25.132 6.026 33.253-4.148 25.049-31.381 43.63-49.449 82.757-49.449 30.764 0 68.816 19.799 68.816 49.631 0 22.552-18.617 34.134-48.993 51.164-35.423 19.86-82.299 44.576-82.299 106.405V320c0 13.255 10.745 24 24 24h72.471c13.255 0 24-10.745 24-24v-5.773c0-42.86 125.268-44.645 125.268-160.627C377.504 66.256 286.902 0 202.021 0zM192 373.459c-38.196 0-69.271 31.075-69.271 69.271 0 38.195 31.075 69.27 69.271 69.27s69.271-31.075 69.271-69.271-31.075-69.27-69.271-69.27z"},"child":[]}]})(props);
}function FaMinus (props) {
  return GenIcon({"attr":{"viewBox":"0 0 448 512"},"child":[{"tag":"path","attr":{"d":"M416 208H32c-17.67 0-32 14.33-32 32v32c0 17.67 14.33 32 32 32h384c17.67 0 32-14.33 32-32v-32c0-17.67-14.33-32-32-32z"},"child":[]}]})(props);
}function FaMicrochip (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M416 48v416c0 26.51-21.49 48-48 48H144c-26.51 0-48-21.49-48-48V48c0-26.51 21.49-48 48-48h224c26.51 0 48 21.49 48 48zm96 58v12a6 6 0 0 1-6 6h-18v6a6 6 0 0 1-6 6h-42V88h42a6 6 0 0 1 6 6v6h18a6 6 0 0 1 6 6zm0 96v12a6 6 0 0 1-6 6h-18v6a6 6 0 0 1-6 6h-42v-48h42a6 6 0 0 1 6 6v6h18a6 6 0 0 1 6 6zm0 96v12a6 6 0 0 1-6 6h-18v6a6 6 0 0 1-6 6h-42v-48h42a6 6 0 0 1 6 6v6h18a6 6 0 0 1 6 6zm0 96v12a6 6 0 0 1-6 6h-18v6a6 6 0 0 1-6 6h-42v-48h42a6 6 0 0 1 6 6v6h18a6 6 0 0 1 6 6zM30 376h42v48H30a6 6 0 0 1-6-6v-6H6a6 6 0 0 1-6-6v-12a6 6 0 0 1 6-6h18v-6a6 6 0 0 1 6-6zm0-96h42v48H30a6 6 0 0 1-6-6v-6H6a6 6 0 0 1-6-6v-12a6 6 0 0 1 6-6h18v-6a6 6 0 0 1 6-6zm0-96h42v48H30a6 6 0 0 1-6-6v-6H6a6 6 0 0 1-6-6v-12a6 6 0 0 1 6-6h18v-6a6 6 0 0 1 6-6zm0-96h42v48H30a6 6 0 0 1-6-6v-6H6a6 6 0 0 1-6-6v-12a6 6 0 0 1 6-6h18v-6a6 6 0 0 1 6-6z"},"child":[]}]})(props);
}function FaInfoCircle (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M256 8C119.043 8 8 119.083 8 256c0 136.997 111.043 248 248 248s248-111.003 248-248C504 119.083 392.957 8 256 8zm0 110c23.196 0 42 18.804 42 42s-18.804 42-42 42-42-18.804-42-42 18.804-42 42-42zm56 254c0 6.627-5.373 12-12 12h-88c-6.627 0-12-5.373-12-12v-24c0-6.627 5.373-12 12-12h12v-64h-12c-6.627 0-12-5.373-12-12v-24c0-6.627 5.373-12 12-12h64c6.627 0 12 5.373 12 12v100h12c6.627 0 12 5.373 12 12v24z"},"child":[]}]})(props);
}function FaGamepad (props) {
  return GenIcon({"attr":{"viewBox":"0 0 640 512"},"child":[{"tag":"path","attr":{"d":"M480.07 96H160a160 160 0 1 0 114.24 272h91.52A160 160 0 1 0 480.07 96zM248 268a12 12 0 0 1-12 12h-52v52a12 12 0 0 1-12 12h-24a12 12 0 0 1-12-12v-52H84a12 12 0 0 1-12-12v-24a12 12 0 0 1 12-12h52v-52a12 12 0 0 1 12-12h24a12 12 0 0 1 12 12v52h52a12 12 0 0 1 12 12zm216 76a40 40 0 1 1 40-40 40 40 0 0 1-40 40zm64-96a40 40 0 1 1 40-40 40 40 0 0 1-40 40z"},"child":[]}]})(props);
}function FaFileAlt (props) {
  return GenIcon({"attr":{"viewBox":"0 0 384 512"},"child":[{"tag":"path","attr":{"d":"M224 136V0H24C10.7 0 0 10.7 0 24v464c0 13.3 10.7 24 24 24h336c13.3 0 24-10.7 24-24V160H248c-13.2 0-24-10.8-24-24zm64 236c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12v8zm0-64c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12v8zm0-72v8c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12zm96-114.1v6.1H256V0h6.1c6.4 0 12.5 2.5 17 7l97.9 98c4.5 4.5 7 10.6 7 16.9z"},"child":[]}]})(props);
}function FaExclamationTriangle (props) {
  return GenIcon({"attr":{"viewBox":"0 0 576 512"},"child":[{"tag":"path","attr":{"d":"M569.517 440.013C587.975 472.007 564.806 512 527.94 512H48.054c-36.937 0-59.999-40.055-41.577-71.987L246.423 23.985c18.467-32.009 64.72-31.951 83.154 0l239.94 416.028zM288 354c-25.405 0-46 20.595-46 46s20.595 46 46 46 46-20.595 46-46-20.595-46-46-46zm-43.673-165.346l7.418 136c.347 6.364 5.609 11.346 11.982 11.346h48.546c6.373 0 11.635-4.982 11.982-11.346l7.418-136c.375-6.874-5.098-12.654-11.982-12.654h-63.383c-6.884 0-12.356 5.78-11.981 12.654z"},"child":[]}]})(props);
}function FaDownload (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M216 0h80c13.3 0 24 10.7 24 24v168h87.7c17.8 0 26.7 21.5 14.1 34.1L269.7 378.3c-7.5 7.5-19.8 7.5-27.3 0L90.1 226.1c-12.6-12.6-3.7-34.1 14.1-34.1H192V24c0-13.3 10.7-24 24-24zm296 376v112c0 13.3-10.7 24-24 24H24c-13.3 0-24-10.7-24-24V376c0-13.3 10.7-24 24-24h146.7l49 49c20.1 20.1 52.5 20.1 72.6 0l49-49H488c13.3 0 24 10.7 24 24zm-124 88c0-11-9-20-20-20s-20 9-20 20 9 20 20 20 20-9 20-20zm64 0c0-11-9-20-20-20s-20 9-20 20 9 20 20 20 20-9 20-20z"},"child":[]}]})(props);
}function FaChevronRight (props) {
  return GenIcon({"attr":{"viewBox":"0 0 320 512"},"child":[{"tag":"path","attr":{"d":"M285.476 272.971L91.132 467.314c-9.373 9.373-24.569 9.373-33.941 0l-22.667-22.667c-9.357-9.357-9.375-24.522-.04-33.901L188.505 256 34.484 101.255c-9.335-9.379-9.317-24.544.04-33.901l22.667-22.667c9.373-9.373 24.569-9.373 33.941 0L285.475 239.03c9.373 9.372 9.373 24.568.001 33.941z"},"child":[]}]})(props);
}function FaChevronDown (props) {
  return GenIcon({"attr":{"viewBox":"0 0 448 512"},"child":[{"tag":"path","attr":{"d":"M207.029 381.476L12.686 187.132c-9.373-9.373-9.373-24.569 0-33.941l22.667-22.667c9.357-9.357 24.522-9.375 33.901-.04L224 284.505l154.745-154.021c9.379-9.335 24.544-9.317 33.901.04l22.667 22.667c9.373 9.373 9.373 24.569 0 33.941L240.971 381.476c-9.373 9.372-24.569 9.372-33.942 0z"},"child":[]}]})(props);
}function FaCheck (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M173.898 439.404l-166.4-166.4c-9.997-9.997-9.997-26.206 0-36.204l36.203-36.204c9.997-9.998 26.207-9.998 36.204 0L192 312.69 432.095 72.596c9.997-9.997 26.207-9.997 36.204 0l36.203 36.204c9.997 9.997 9.997 26.206 0 36.204l-294.4 294.401c-9.998 9.997-26.207 9.997-36.204-.001z"},"child":[]}]})(props);
}function FaBan (props) {
  return GenIcon({"attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M256 8C119.034 8 8 119.033 8 256s111.034 248 248 248 248-111.034 248-248S392.967 8 256 8zm130.108 117.892c65.448 65.448 70 165.481 20.677 235.637L150.47 105.216c70.204-49.356 170.226-44.735 235.638 20.676zM125.892 386.108c-65.448-65.448-70-165.481-20.677-235.637L361.53 406.784c-70.203 49.356-170.226 44.736-235.638-20.676z"},"child":[]}]})(props);
}

// ---------------------------------------------------------------------------
//  Paleta (Joy-Con) y utilidades
// ---------------------------------------------------------------------------
const C = {
    azul: "#0AB9E6",
    rojo: "#FF3C28",
    verde: "#3DDC84",
    violeta: "#B47BFF",
    naranja: "#FF8A3D",
    turquesa: "#2EE6C8",
    dorado: "#F5C518",
    carbon1: "#262628",
    carbon2: "#141416",
    texto: "#EDEFF2",
    texto2: "#B8BCC2",
    gris: "#8A8F98",
};
// color de cada jugador en el boton "Mandos"
const COLOR_JUGADOR = [
    "#0AB9E6", // 1 azul
    "#3DDC84", // 2 verde
    "#B47BFF", // 3 violeta
    "#FF8A3D", // 4 naranja
];
function hexA(hex, alfa) {
    const h = hex.replace("#", "");
    const completo = h.length === 3
        ? h
            .split("")
            .map((c) => c + c)
            .join("")
        : h;
    const n = parseInt(completo, 16);
    const r = (n >> 16) & 255;
    const g = (n >> 8) & 255;
    const b = n & 255;
    return `rgba(${r}, ${g}, ${b}, ${alfa})`;
}
function colorDe(m) {
    switch (m.familia) {
        case "playstation":
            return C.azul;
        case "xbox":
            return C.verde;
        case "switch":
            return C.rojo;
        case "steam":
            return C.violeta;
        default:
            return C.gris;
    }
}
function IconoFamilia(props) {
    switch (props.familia) {
        case "playstation":
            return SP_JSX.jsx(FaPlaystation, { size: props.size });
        case "xbox":
            return SP_JSX.jsx(FaXbox, { size: props.size });
        case "steam":
            return SP_JSX.jsx(FaSteam, { size: props.size });
        case "switch":
        case "integrado":
            return SP_JSX.jsx(FaGamepad, { size: props.size });
        default:
            return SP_JSX.jsx(FaQuestion, { size: props.size });
    }
}
function colorConexion(conexion) {
    if (conexion.startsWith("Bluetooth"))
        return C.azul;
    if (conexion === "USB")
        return C.verde;
    if (conexion.startsWith("Virtual"))
        return C.violeta;
    return C.gris;
}
function macCorta(serie) {
    const partes = (serie || "").split(":");
    if (partes.length >= 2) {
        return `…${partes[partes.length - 2]}:${partes[partes.length - 1]}`;
    }
    return serie;
}
const ESTILOS = `
@keyframes ede-latido {
  0%, 100% { opacity: .88; transform: scale(1); }
  50% { opacity: 1; transform: scale(1.15); }
}
@keyframes ede-aparecer {
  from { opacity: 0; transform: translateY(-2px); }
  to   { opacity: 1; transform: none; }
}
.ede-estrella { animation: ede-latido 2.6s ease-in-out infinite; }
/* el boton no pinta nada: solo se ve la tarjeta de dentro */
.ede-boton, .ede-cab {
  padding: 0 !important;
  background: transparent !important;
  box-shadow: none !important;
  border-radius: 16px !important;
  width: 100%;
}
/* foco: solo el borde (sin fondo blanco de Steam) */
.ede-foco-cab {
  border-radius: 10px !important;
  box-shadow: 0 0 0 1px var(--ede-acento, #0AB9E6),
              0 0 10px var(--ede-acento-halo, rgba(10,185,230,0.45)) !important;
}
/* --- tarjetas: foco y micro-animaciones (estilo PdC) --- */
.ede-tarjeta { transition: box-shadow 140ms ease, transform 140ms ease, border-color 140ms ease; }
.ede-foco .ede-tarjeta,
.ede-panel .gpfocus .ede-tarjeta,
.ede-celda:hover .ede-tarjeta {
  border-color: var(--ede-acento, #0AB9E6) !important;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.22),
              0 0 0 2px var(--ede-acento, #0AB9E6),
              0 0 14px var(--ede-acento-halo, rgba(10,185,230,0.45)) !important;
  transform: scale(1.02);
}
.ede-icono-tile { display: inline-flex; transition: transform 160ms ease, filter 160ms ease; }
.ede-foco .ede-icono-tile,
.ede-panel .gpfocus .ede-icono-tile { transform: scale(1.08); filter: brightness(1.12); }
.ede-icono-caja { display: inline-flex; align-items: center; justify-content: center; transition: box-shadow 160ms ease; }
.ede-foco .ede-icono-caja,
.ede-panel .gpfocus .ede-icono-caja { box-shadow: 0 0 12px var(--ede-glow, rgba(10,185,230,0.55)); }
.ede-foco .ede-anim-pop,
.ede-panel .gpfocus .ede-anim-pop { animation: ede-icono-pop 420ms cubic-bezier(.2,.8,.2,1) both; }
.ede-foco .ede-anim-giro,
.ede-panel .gpfocus .ede-anim-giro { animation: ede-icono-giro 480ms ease-out both; }
.ede-foco .ede-anim-latido,
.ede-panel .gpfocus .ede-anim-latido { animation: ede-icono-latido 460ms ease-out both; }
.ede-foco .ede-anim-barrido,
.ede-panel .gpfocus .ede-anim-barrido { animation: ede-icono-barrido 380ms ease-out both; }
@keyframes ede-icono-pop { 0% { transform: scale(.82); } 60% { transform: scale(1.14); } 100% { transform: scale(1); } }
@keyframes ede-icono-giro { 0% { transform: rotate(-30deg); } 70% { transform: rotate(5deg); } 100% { transform: rotate(0); } }
@keyframes ede-icono-latido { 0% { transform: scale(.9); opacity: .7; } 55% { transform: scale(1.12); opacity: 1; } 100% { transform: scale(1); } }
@keyframes ede-icono-barrido { 0% { transform: translateY(3px); opacity: .5; } 100% { transform: translateY(0); opacity: 1; } }
/* boton pequeno de accion en la cabecera */
.ede-icono-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: rgba(255,255,255,0.06);
  box-shadow: inset 0 0 0 1px rgba(255,255,255,0.10);
  color: rgba(255,255,255,0.72);
  transition: box-shadow 140ms ease, color 140ms ease;
}
.ede-icono-btn-foco {
  color: #ffffff;
  box-shadow: inset 0 0 0 1px var(--ede-acento, #0AB9E6),
              0 0 9px var(--ede-acento-halo, rgba(10,185,230,0.45));
}
/* iconos de jugador del boton "Mandos" */
.ede-slot { display: inline-flex; transition: color 180ms ease, opacity 180ms ease, filter 180ms ease; }
.ede-slot.off { color: rgba(255,255,255,0.20); }
.ede-slot.on { filter: drop-shadow(0 0 5px currentColor); }
.ede-slot.pulso { animation: ede-slot-vibra 480ms ease-in-out; }
@keyframes ede-slot-vibra {
  0%, 100% { transform: translateX(0) rotate(0); }
  15% { transform: translateX(-2px) rotate(-8deg); }
  30% { transform: translateX(2px) rotate(8deg); }
  45% { transform: translateX(-2px) rotate(-6deg); }
  60% { transform: translateX(2px) rotate(6deg); }
  75% { transform: translateX(-1px) rotate(-3deg); }
}
@media (prefers-reduced-motion: reduce) {
  .ede-slot.pulso { animation: none; }
  .ede-tarjeta, .ede-icono-tile, .ede-icono-caja { transition: none; }
  .ede-foco .ede-tarjeta,
  .ede-panel .gpfocus .ede-tarjeta { transform: none; }
  .ede-foco .ede-icono-tile,
  .ede-foco .ede-anim-pop,
  .ede-foco .ede-anim-giro,
  .ede-foco .ede-anim-latido,
  .ede-foco .ede-anim-barrido,
  .ede-panel .gpfocus .ede-icono-tile,
  .ede-panel .gpfocus .ede-anim-pop,
  .ede-panel .gpfocus .ede-anim-giro,
  .ede-panel .gpfocus .ede-anim-latido,
  .ede-panel .gpfocus .ede-anim-barrido { animation: none; transform: none; }
}
.ede-aparecer { animation: ede-aparecer 150ms ease-out; }
@media (prefers-reduced-motion: reduce) {
  .ede-estrella, .ede-aparecer { animation: none; }
}
`;
// ---------------------------------------------------------------------------
//  Piezas visuales
// ---------------------------------------------------------------------------
/** Icono dentro de un circulo (estilo ajustes de Switch). */
function CirculoIcono(props) {
    const lado = props.lado ?? 26;
    return (SP_JSX.jsx("span", { style: {
            width: `${lado}px`,
            height: `${lado}px`,
            borderRadius: "50%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flex: "0 0 auto",
            background: hexA(props.color, 0.18),
            border: `1px solid ${hexA(props.color, 0.45)}`,
            color: props.color,
        }, children: props.children }));
}
/** Tarjeta de aviso (icono a la izquierda), como las notificaciones de Switch. */
function Aviso(props) {
    const color = props.tono === "atencion" ? C.rojo : C.azul;
    return (SP_JSX.jsxs("div", { onClick: props.onClick, style: {
            display: "flex",
            alignItems: "flex-start",
            gap: "10px",
            padding: "9px 12px",
            borderRadius: "14px",
            border: "1px solid rgba(128,128,128,0.22)",
            background: "linear-gradient(120deg, rgba(22,22,24,0.92), rgba(30,30,33,0.78))",
            color: C.texto,
            fontSize: "0.78em",
            lineHeight: 1.4,
            whiteSpace: "pre-wrap",
        }, children: [SP_JSX.jsx(CirculoIcono, { color: color, lado: 26, children: props.tono === "atencion" ? (SP_JSX.jsx(FaExclamationTriangle, { size: 11 })) : (SP_JSX.jsx(FaInfoCircle, { size: 11 })) }), SP_JSX.jsx("div", { style: { minWidth: 0 }, children: props.children })] }));
}
/** Glifo circular tipo prompt de Switch. */
function GlifoA() {
    return (SP_JSX.jsx("span", { style: {
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            width: "15px",
            height: "15px",
            borderRadius: "50%",
            background: "#fff",
            color: "#1a1a1a",
            fontSize: "0.62em",
            fontWeight: 800,
            lineHeight: 1,
            flex: "0 0 auto",
        }, children: "A" }));
}
function IconoConexion(props) {
    const s = props.size ?? 9;
    if (props.conexion.startsWith("Bluetooth"))
        return SP_JSX.jsx(FaBluetoothB, { size: s });
    if (props.conexion === "USB")
        return SP_JSX.jsx(FaUsb, { size: s });
    if (props.conexion.startsWith("Virtual"))
        return SP_JSX.jsx(FaSteam, { size: s });
    return SP_JSX.jsx(FaMicrochip, { size: s });
}
function IconoTile(props) {
    const color = colorDe(props.m);
    return (SP_JSX.jsx("div", { style: {
            width: `${props.lado}px`,
            height: `${props.lado}px`,
            borderRadius: "9px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            flex: "0 0 auto",
            background: `linear-gradient(145deg, ${hexA(color, 0.35)}, ${hexA(color, 0.06)})`,
            border: `1px solid ${hexA(color, 0.5)}`,
            boxShadow: `inset 0 0 10px ${hexA(color, 0.15)}`,
            color,
        }, children: SP_JSX.jsx(IconoFamilia, { familia: props.m.familia, size: props.lado * 0.55 }) }));
}
function estiloBadge(color) {
    return {
        position: "absolute",
        top: "5px",
        right: "5px",
        minWidth: "18px",
        height: "18px",
        padding: "0 4px",
        borderRadius: "999px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: "0.64em",
        fontWeight: 800,
        lineHeight: 1,
        color,
        background: "rgba(0,0,0,0.55)",
        border: `1px solid ${hexA(color, 0.7)}`,
        boxShadow: `0 0 7px ${hexA(color, 0.35)}`,
        boxSizing: "border-box",
    };
}
/** Arriba a la derecha: estrella si es el principal; si no, su jugador. */
function Badge(props) {
    const { m } = props;
    if (m.es_principal) {
        return (SP_JSX.jsx(FaStar, { className: "ede-estrella", style: {
                position: "absolute",
                top: "4px",
                right: "6px",
                color: C.dorado,
                fontSize: "0.88em",
                filter: `drop-shadow(0 0 4px ${hexA(C.dorado, 0.9)})`,
            } }));
    }
    if (m.jugador) {
        return SP_JSX.jsx("div", { style: estiloBadge(C.azul), children: m.jugador });
    }
    return (SP_JSX.jsx("div", { style: { ...estiloBadge(C.gris), width: "18px", padding: 0 }, children: m.clase === "Integrado" ? SP_JSX.jsx(FaBan, { size: 8 }) : SP_JSX.jsx(FaMinus, { size: 8 }) }));
}
function estiloTarjeta(color) {
    return {
        position: "relative",
        borderRadius: "16px",
        boxSizing: "border-box",
        overflow: "hidden",
        color: C.texto,
        border: "1px solid rgba(255,255,255,0.10)",
        background: `radial-gradient(130% 100% at 100% 0%, ${hexA(color, 0.14)}, transparent 62%), ` +
            `linear-gradient(155deg, ${C.carbon1}, ${C.carbon2})`,
        boxShadow: "0 1px 3px rgba(0,0,0,0.45)",
        transition: "border-color 180ms ease, box-shadow 180ms ease",
    };
}
// --- tarjeta cuadrada (2 o mas mandos) -------------------------------------
function MandoCuadrado(props) {
    const { m, mostrarMac, destello, onClick } = props;
    const color = colorDe(m);
    return (SP_JSX.jsx(BotonTarjeta, { onClick: onClick, children: SP_JSX.jsxs("div", { className: "ede-tarjeta", style: {
                ...estiloTarjeta(color),
                ...(destello
                    ? {
                        border: `1px solid ${C.azul}`,
                        boxShadow: `0 0 16px ${hexA(C.azul, 0.6)}`,
                    }
                    : null),
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                minHeight: "96px",
                width: "100%",
                padding: 0,
                textAlign: "center",
            }, children: [SP_JSX.jsx(Badge, { m: m }), SP_JSX.jsxs("div", { style: {
                        display: "flex",
                        flexDirection: "column",
                        alignItems: "center",
                        justifyContent: "center",
                        gap: "3px",
                        flex: 1,
                        padding: "10px 5px 5px",
                    }, children: [SP_JSX.jsx(IconoTile, { m: m, lado: 34 }), SP_JSX.jsxs("div", { style: {
                                display: "flex",
                                alignItems: "center",
                                gap: "3px",
                                fontSize: "0.6em",
                                color: colorConexion(m.conexion),
                            }, children: [SP_JSX.jsx(IconoConexion, { conexion: m.conexion, size: 8 }), m.conexion] }), !m.jugador ? (SP_JSX.jsx("div", { style: {
                                fontSize: "0.55em",
                                color: C.gris,
                                opacity: 0.85,
                                lineHeight: 1,
                            }, children: "Desactivado" })) : null, mostrarMac && m.serie ? (SP_JSX.jsx("div", { style: {
                                fontSize: "0.53em",
                                color: C.texto2,
                                opacity: 0.5,
                                lineHeight: 1,
                            }, children: macCorta(m.serie) })) : null] }), m.familia === "desconocido" ? (SP_JSX.jsx("div", { style: {
                        padding: "3px 5px",
                        background: "rgba(0,0,0,0.38)",
                        borderTop: `1px solid ${hexA(color, 0.3)}`,
                        fontSize: "0.64em",
                        fontWeight: 700,
                        lineHeight: 1.2,
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                    }, children: m.sdl || m.nombre || m.clase })) : null] }) }));
}
// Envoltorio comun: un Focusable sin nada de Steam (sin fondo ni anillo) y
// dentro la tarjeta. Asi todos los botones se ven igual y el foco es el borde.
function BotonTarjeta(props) {
    return (SP_JSX.jsx(DFL.Focusable, { className: "ede-boton", focusClassName: "ede-foco", noFocusRing: true, onActivate: props.onClick, onClick: props.onClick, style: { width: "100%", padding: 0, background: "transparent" }, children: props.children }));
}
function TarjetaBase(props) {
    const color = props.color ?? C.azul;
    return (SP_JSX.jsx(BotonTarjeta, { onClick: props.onClick, children: SP_JSX.jsxs("div", { className: "ede-tarjeta", style: {
                ...estiloTarjeta(color),
                display: "flex",
                alignItems: "center",
                gap: "11px",
                width: "100%",
                padding: "11px 12px",
                textAlign: "left",
            }, children: [SP_JSX.jsx(IconoTarjeta, { icono: props.icono, color: color, anim: props.anim }), SP_JSX.jsxs("div", { style: { minWidth: 0, flex: 1 }, children: [SP_JSX.jsx("div", { style: { fontSize: "0.8em", fontWeight: 700, lineHeight: 1.2 }, children: props.titulo }), props.detalle ? (SP_JSX.jsx("div", { style: { fontSize: "0.68em", opacity: 0.7, lineHeight: 1.2 }, children: props.detalle })) : null] }), props.flecha ? (SP_JSX.jsx("span", { style: { opacity: 0.45, display: "flex", flex: "0 0 auto" }, children: SP_JSX.jsx(FaChevronRight, { size: 11 }) })) : null] }) }));
}
function BotonAccion(props) {
    return (SP_JSX.jsx(TarjetaBase, { icono: props.icono, titulo: props.texto, color: props.color, anim: "pop", onClick: props.onClick }));
}
// --- icono de la maquina integrada -----------------------------------------
function IconoPortatil(props) {
    const lado = props.size ?? 17;
    return (SP_JSX.jsxs("svg", { width: lado, height: lado, viewBox: "0 0 24 24", fill: "currentColor", "aria-hidden": "true", children: [SP_JSX.jsx("path", { d: "M7 3h10a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4h-1.5a2 2 0 0 1-1.7-.9l-.8-1.2a1.2 1.2 0 0 0-2 0l-.8 1.2a2 2 0 0 1-1.7.9H7a4 4 0 0 1-4-4V7a4 4 0 0 1 4-4Zm0 1.8A2.2 2.2 0 0 0 4.8 7v10A2.2 2.2 0 0 0 7 19.2h.8l.8-1.2a3 3 0 0 1 4.8 0l.8 1.2H17a2.2 2.2 0 0 0 2.2-2.2V7A2.2 2.2 0 0 0 17 4.8H7Z" }), SP_JSX.jsx("rect", { x: "6.6", y: "6.4", width: "10.8", height: "6.8", rx: "1.2" }), SP_JSX.jsx("circle", { cx: "8.1", cy: "16.3", r: "1.05" }), SP_JSX.jsx("circle", { cx: "15.9", cy: "16.3", r: "1.05" })] }));
}
function textoMaquina(m, nombre) {
    return `${m?.vendor ?? ""} ${m?.producto ?? ""} ${m?.placa ?? ""} ${nombre}`.toLowerCase();
}
// "ROG Ally RC71L_RC71L" -> "ROG Ally"; "ROG Ally X RC72LA_RC72LA" -> "ROG Ally X"
function limpiarModelo(producto) {
    return (producto || "")
        .replace(/\s+[A-Z0-9][A-Z0-9_-]{4,}$/, "")
        .trim();
}
function nombreMaquina(m) {
    if (!m)
        return "";
    const t = textoMaquina(m, "");
    if (t.includes("valve") ||
        t.includes("jupiter") ||
        t.includes("galileo") ||
        t.includes("steam deck")) {
        return "Steam Deck";
    }
    if (t.includes("asustek") || t.includes("asus")) {
        return limpiarModelo(m.producto) || limpiarModelo(m.placa) || "ROG Ally";
    }
    if (t.includes("micro-star") || t.includes("msi")) {
        return limpiarModelo(m.producto) || limpiarModelo(m.placa) || "MSI Claw";
    }
    if (t.includes("lenovo") || t.includes("legion")) {
        // Lenovo suele traer un codigo en product_name ("83E1"): mejor la placa.
        return limpiarModelo(m.placa) || limpiarModelo(m.producto) || "Legion Go";
    }
    return limpiarModelo(m.producto) || limpiarModelo(m.placa);
}
function IconoMaquina(props) {
    const t = textoMaquina(props.maquina, props.nombre);
    const lado = props.size ?? 17;
    if (t.includes("valve") ||
        t.includes("jupiter") ||
        t.includes("galileo") ||
        t.includes("steam deck") ||
        t.includes("deck controller")) {
        return SP_JSX.jsx(SiSteamdeck, { size: lado });
    }
    if (t.includes("asustek") ||
        t.includes("asus") ||
        t.includes("rog") ||
        t.includes("ally")) {
        return SP_JSX.jsx(SiAsus, { size: lado });
    }
    if (t.includes("micro-star") || t.includes("msi") || t.includes("claw")) {
        return SP_JSX.jsx(SiMsi, { size: lado });
    }
    if (t.includes("lenovo") || t.includes("legion")) {
        return SP_JSX.jsx(SiLenovo, { size: lado });
    }
    if (t.includes("xbox"))
        return SP_JSX.jsx(FaXbox, { size: lado });
    return SP_JSX.jsx(IconoPortatil, { size: lado });
}
// --- boton de icono pequeno (acciones de cabecera) -------------------------
function BotonIcono(props) {
    return (SP_JSX.jsx(DFL.Focusable, { className: "ede-icono-btn", focusClassName: "ede-icono-btn-foco", noFocusRing: true, onActivate: props.onClick, onClick: props.onClick, "aria-label": props.titulo, children: props.icono }));
}
// --- chip de estado (mismo diseno que el del dispositivo) ------------------
function ChipEstado(props) {
    return (SP_JSX.jsxs("div", { style: {
            display: "inline-flex",
            alignItems: "center",
            gap: "6px",
            minHeight: "24px",
            maxWidth: "100%",
            padding: "3px 9px",
            borderRadius: "999px",
            background: "rgba(255,255,255,0.04)",
            boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.10)",
            boxSizing: "border-box",
        }, children: [SP_JSX.jsx("span", { style: { display: "flex", flex: "0 0 auto", color: props.color }, children: props.icono }), SP_JSX.jsx("span", { style: {
                    fontSize: "0.72em",
                    fontWeight: 650,
                    whiteSpace: "nowrap",
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                }, children: props.texto })] }));
}
// --- tarjeta del mando integrado -------------------------------------------
function TarjetaIntegrado(props) {
    const detalle = props.modo === "ignorar" || (props.detectado && !props.jugador)
        ? "Desactivado"
        : props.modo === "primero"
            ? "Jugador 1"
            : "Último jugador";
    return (SP_JSX.jsx(TarjetaAccion, { color: C.naranja, icono: props.icono, anim: "pop", titulo: "Integrado", detalle: detalle, onClick: props.onClick }));
}
function IconoTarjeta(props) {
    return (SP_JSX.jsx("span", { className: "ede-icono-tile", children: SP_JSX.jsx("span", { className: `ede-anim-${props.anim ?? "pop"}`, children: SP_JSX.jsx("span", { className: "ede-icono-caja", style: {
                    width: "36px",
                    height: "36px",
                    borderRadius: "11px",
                    background: props.color,
                    color: "#ffffff",
                    flex: "0 0 auto",
                    "--ede-glow": hexA(props.color, 0.6),
                }, children: props.icono }) }) }));
}
function TarjetaAccion(props) {
    const color = props.color ?? C.azul;
    return (SP_JSX.jsx(BotonTarjeta, { onClick: props.onClick, children: SP_JSX.jsx("div", { className: "ede-tarjeta", style: {
                ...estiloTarjeta(color),
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                minHeight: "96px",
                width: "100%",
                padding: 0,
                textAlign: "center",
            }, children: SP_JSX.jsxs("div", { style: {
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: "6px",
                    padding: "10px 6px",
                    width: "100%",
                }, children: [SP_JSX.jsx(IconoTarjeta, { icono: props.icono, color: color, anim: props.anim }), SP_JSX.jsx("div", { style: { fontSize: "0.7em", fontWeight: 700, lineHeight: 1.15 }, children: props.titulo }), props.detalle ? (SP_JSX.jsx("div", { style: { fontSize: "0.62em", opacity: 0.7, lineHeight: 1.15 }, children: props.detalle })) : null] }) }) }));
}
// --- rejilla de 2 columnas -------------------------------------------------
function Rejilla(props) {
    return (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: {
                display: "grid",
                gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                gap: "6px",
                width: "100%",
            }, children: props.children }) }));
}
// --- seccion colapsable ----------------------------------------------------
function Seccion(props) {
    const cabecera = (SP_JSX.jsxs("div", { style: {
            display: "flex",
            alignItems: "center",
            gap: "9px",
            width: "100%",
        }, children: [SP_JSX.jsx(CirculoIcono, { color: props.color ?? C.azul, lado: 26, children: props.icono }), SP_JSX.jsx("span", { style: { fontWeight: 700 }, children: props.titulo }), props.resumen ? (SP_JSX.jsx("span", { style: {
                    marginLeft: "auto",
                    fontSize: "0.7em",
                    opacity: 0.55,
                    whiteSpace: "nowrap",
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                }, children: props.resumen })) : null, props.accion ? (SP_JSX.jsx("span", { style: {
                    marginLeft: props.resumen ? "6px" : "auto",
                    display: "flex",
                    flex: "0 0 auto",
                }, children: props.accion })) : null, props.onToggle ? (SP_JSX.jsx("span", { style: {
                    marginLeft: props.resumen || props.accion ? "6px" : "auto",
                    opacity: 0.6,
                    display: "flex",
                    flex: "0 0 auto",
                }, children: props.abierta ? SP_JSX.jsx(FaChevronDown, { size: 10 }) : SP_JSX.jsx(FaChevronRight, { size: 10 }) })) : null] }));
    return (SP_JSX.jsxs(DFL.PanelSection, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: props.onToggle ? (SP_JSX.jsx(DFL.Focusable, { className: "ede-cab", focusClassName: "ede-foco-cab", noFocusRing: true, onActivate: props.onToggle, onClick: props.onToggle, style: { width: "100%", padding: 0, background: "transparent" }, children: cabecera })) : (cabecera) }), SP_JSX.jsx("div", { style: {
                    height: "1px",
                    background: "rgba(128,128,128,0.16)",
                    margin: "0 6px 6px",
                } }), props.abierta ? (SP_JSX.jsx("div", { className: "ede-aparecer", children: props.children })) : null] }));
}
// ---------------------------------------------------------------------------
//  Ventana emergente de texto (con scroll: D-pad, stick o dedo)
// ---------------------------------------------------------------------------
function VentanaTexto(props) {
    const texto = (props.texto || "").replace(/\s+$/, "");
    const esLog = Boolean(props.recientePrimero);
    const ref = SP_REACT.useRef(null);
    // El log abre por el final: lo mas reciente (el ultimo aplicar) se ve ya.
    SP_REACT.useEffect(() => {
        if (!esLog)
            return;
        const el = ref.current;
        if (el)
            el.scrollTop = el.scrollHeight;
    }, [esLog, texto]);
    // El Focusable es el unico elemento enfocable del log; mueve el textarea.
    // El textarea tiene tabIndex=-1 para no robar el foco ni abrir el teclado.
    const mover = (evt) => {
        const el = ref.current;
        if (!el)
            return;
        const paso = Math.max(40, Math.floor(el.clientHeight * 0.75));
        if (evt.detail?.button === DFL.GamepadButton.DIR_UP) {
            if (el.scrollTop > 0) {
                el.scrollTop -= paso;
                evt.stopPropagation();
            }
        }
        else if (evt.detail?.button === DFL.GamepadButton.DIR_DOWN) {
            if (el.scrollTop + el.clientHeight < el.scrollHeight - 1) {
                el.scrollTop += paso;
                evt.stopPropagation();
            }
        }
    };
    return (SP_JSX.jsxs(DFL.ModalRoot, { strTitle: props.titulo, bAllowFullSize: true, onCancel: props.onCerrar, children: [SP_JSX.jsxs(DFL.DialogBody, { style: {
                    height: "58vh",
                    maxHeight: "58vh",
                    padding: 0,
                    overflow: "hidden",
                    display: "flex",
                    flexDirection: "column",
                }, children: [esLog ? (SP_JSX.jsx("div", { style: {
                            padding: "4px 12px 0",
                            fontSize: "0.7em",
                            opacity: 0.65,
                        }, children: "D-pad / stick: desplazar \u00B7 B: cerrar" })) : null, SP_JSX.jsx(DFL.Focusable, { preferredFocus: true, onGamepadDirection: mover, style: {
                            flex: 1,
                            minHeight: 0,
                            display: "flex",
                            flexDirection: "column",
                        }, children: SP_JSX.jsx("textarea", { ref: ref, readOnly: true, tabIndex: -1, rows: 20, value: texto || "(vacio)", wrap: "soft", spellCheck: false, style: {
                                width: "100%",
                                height: "50vh",
                                minHeight: "260px",
                                flex: 1,
                                resize: "none",
                                overflowY: "auto",
                                margin: "8px 12px",
                                padding: "8px 10px",
                                border: "1px solid rgba(128,128,128,0.25)",
                                borderRadius: "8px",
                                background: "rgba(0,0,0,0.18)",
                                color: "inherit",
                                fontFamily: "monospace",
                                fontSize: "0.82em",
                                lineHeight: 1.35,
                            } }) })] }), esLog ? null : (SP_JSX.jsx(DFL.DialogFooter, { children: SP_JSX.jsx(DFL.DialogButtonPrimary, { onClick: props.onCerrar, children: "Cerrar" }) }))] }));
}
function abrirVentana(titulo, texto, recientePrimero = false) {
    const cierre = { f: () => { } };
    const res = DFL.showModal(SP_JSX.jsx(VentanaTexto, { titulo: titulo, texto: texto, recientePrimero: recientePrimero, onCerrar: () => cierre.f() }));
    cierre.f = res.Close;
}
// ---------------------------------------------------------------------------
//  Ventana de asignacion (Cemu / Dolphin)
// ---------------------------------------------------------------------------
function VentanaAsignacion(props) {
    const [planes, setPlanes] = SP_REACT.useState(props.planes);
    const [ocupado, setOcupado] = SP_REACT.useState(false);
    const [nota, setNota] = SP_REACT.useState("");
    const comprobar = async () => {
        if (ocupado)
            return;
        setOcupado(true);
        setNota("Comprobando…");
        try {
            const nuevo = await call("comprobar");
            setPlanes(nuevo.planes);
            props.onNuevo(nuevo);
            setNota(nuevo.aviso || "Plan recalculado");
        }
        catch (err) {
            setNota(String(err));
        }
        finally {
            setOcupado(false);
        }
    };
    const bloque = (clave, etiqueta) => {
        const pl = planes?.[clave];
        return (SP_JSX.jsxs("div", { style: { marginBottom: "12px" }, children: [SP_JSX.jsx("div", { style: { fontWeight: 700 }, children: etiqueta }), pl ? (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsxs("div", { style: { opacity: 0.6, fontSize: "0.85em" }, children: [pl.modo, " \u00B7 ", pl.fecha, " \u00B7 m\u00E1ximo ", pl.max, " \u00B7", " ", pl.sdl === "ok" ? "SDL ok" : "SDL error"] }), pl.mandos.length === 0 ? (SP_JSX.jsx("div", { style: { color: C.dorado }, children: "Ning\u00FAn mando asignado." })) : (pl.mandos.map((m) => (SP_JSX.jsxs("div", { children: [SP_JSX.jsxs("span", { style: { color: C.azul, fontWeight: 700 }, children: ["M", m.n] }), " ", m.nombre, " ", SP_JSX.jsxs("span", { style: { opacity: 0.5 }, children: ["[", m.clase, "]"] })] }, m.n)))), pl.fuera.map((f) => (SP_JSX.jsxs("div", { style: { color: C.gris, fontSize: "0.92em" }, children: ["fuera: ", f.replace("|", ": ")] }, f))), pl.aviso.map((a) => (SP_JSX.jsx("div", { style: { color: C.dorado, fontSize: "0.92em" }, children: a }, a)))] })) : (SP_JSX.jsx("div", { style: { opacity: 0.6 }, children: "Sin datos todav\u00EDa. Pulsa \u00ABComprobar ahora\u00BB." }))] }, clave));
    };
    return (SP_JSX.jsxs(DFL.ModalRoot, { strTitle: "Asignaci\u00F3n", bAllowFullSize: true, onCancel: props.onCerrar, children: [SP_JSX.jsx(DFL.DialogBody, { children: SP_JSX.jsx(DFL.DialogBodyText, { children: SP_JSX.jsxs("div", { style: {
                            maxHeight: "45vh",
                            overflowY: "auto",
                            fontSize: "0.9em",
                            lineHeight: 1.4,
                        }, children: [bloque("wiiu", "Cemu (Wii U)"), bloque("dolphin", "Dolphin (GC/Wii)"), nota ? (SP_JSX.jsx("div", { style: { marginTop: "6px", opacity: 0.75, fontSize: "0.9em" }, children: nota })) : null] }) }) }), SP_JSX.jsxs(DFL.DialogFooter, { children: [SP_JSX.jsx(DFL.DialogButton, { disabled: ocupado, onClick: () => void comprobar(), children: ocupado ? "Comprobando…" : "Comprobar ahora" }), SP_JSX.jsx(DFL.DialogButtonPrimary, { onClick: props.onCerrar, children: "Cerrar" })] })] }));
}
function abrirAsignacion(planes, onNuevo) {
    const cierre = { f: () => { } };
    const res = DFL.showModal(SP_JSX.jsx(VentanaAsignacion, { planes: planes, onCerrar: () => cierre.f(), onNuevo: onNuevo }));
    cierre.f = res.Close;
}
// ---------------------------------------------------------------------------
//  Panel
// ---------------------------------------------------------------------------
function Content() {
    const [est, setEst] = SP_REACT.useState(null);
    const [ocupado, setOcupado] = SP_REACT.useState(false);
    const [abiertas, setAbiertas] = SP_REACT.useState({});
    const [aviso, setAviso] = SP_REACT.useState("");
    const temporizador = SP_REACT.useRef(null);
    const [destello, setDestello] = SP_REACT.useState(null);
    const [pulsoMando, setPulsoMando] = SP_REACT.useState(0);
    const ultimoN = SP_REACT.useRef(-1);
    const [ultimo, setUltimo] = SP_REACT.useState({});
    const toggle = (id) => setAbiertas((prev) => ({ ...prev, [id]: !prev[id] }));
    // avisos pasajeros: se pintan dentro del panel y se borran solos
    const avisar = (mensaje) => {
        setAviso(mensaje);
        if (temporizador.current)
            clearTimeout(temporizador.current);
        temporizador.current = setTimeout(() => setAviso(""), 5000);
    };
    const limpiarAviso = () => {
        if (temporizador.current)
            clearTimeout(temporizador.current);
        setAviso("");
    };
    const refrescar = async () => {
        try {
            const nuevo = await call("estado");
            setEst(nuevo);
            ultimoN.current = nuevo.mandos.length;
            if (nuevo.aviso)
                avisar(nuevo.aviso);
        }
        catch (e) {
            abrirVentana("Error", String(e));
        }
    };
    SP_REACT.useEffect(() => {
        void refrescar();
    }, []);
    // cada pocos segundos miramos si han conectado/desconectado mandos
    SP_REACT.useEffect(() => {
        const id = setInterval(() => {
            void (async () => {
                try {
                    const n = await call("contar");
                    if (n < 0)
                        return;
                    if (ultimoN.current >= 0 && n !== ultimoN.current) {
                        const nuevo = await call("estado");
                        setEst(nuevo);
                        ultimoN.current = nuevo.mandos.length;
                    }
                    else {
                        ultimoN.current = n;
                    }
                }
                catch {
                    /* silencio: es un sondeo */
                }
            })();
        }, 5000);
        return () => clearInterval(id);
    }, []);
    const conBloqueo = async (fn) => {
        if (ocupado)
            return;
        setOcupado(true);
        try {
            await fn();
        }
        catch (e) {
            abrirVentana("Error", String(e));
        }
        finally {
            setOcupado(false);
        }
    };
    const TOCAR_MS = 1500;
    const vibrar = (m) => {
        void call("vibrar", m.serie, m.puerto)
            .then((r) => {
            if (r.ok)
                return;
            if (r.salida.includes("\n"))
                abrirVentana("No se pudo vibrar", r.salida);
            else
                avisar(r.salida);
        })
            .catch(() => { });
        setDestello(m.serie);
        setTimeout(() => setDestello((d) => (d === m.serie ? null : d)), 420);
    };
    const tocarMando = (m) => conBloqueo(async () => {
        if (m.clase === "Integrado") {
            avisar("El mando integrado no vibra ni se fija por serie: se pone como Player 1 " +
                "con el ajuste «Mando integrado».");
            return;
        }
        if (!m.serie) {
            avisar(`"${m.sdl || m.nombre}" no informa de su serie, asi que no puedo dirigirme a el.`);
            return;
        }
        vibrar(m);
        const ahora = Date.now();
        const anterior = ultimo[m.serie] ?? 0;
        const doble = ahora - anterior < TOCAR_MS;
        setUltimo((u) => ({ ...u, [m.serie]: ahora }));
        if (m.es_principal) {
            avisar("Este ya es el principal.");
            return;
        }
        if (est && est.ds_conectados <= 1) {
            avisar("Con un solo mando conectado, ya es el principal.");
            return;
        }
        if (!doble) {
            avisar("Pulsa otra vez para hacerlo principal.");
            return;
        }
        const nuevo = await call("alternar_principal", m.serie);
        setEst(nuevo);
        if (nuevo.aviso) {
            avisar(nuevo.aviso);
        }
        else {
            const p = nuevo.mandos.find((x) => x.serie === m.serie);
            setUltimo((u) => ({ ...u, [m.serie]: 0 }));
            avisar(`${p?.sdl || p?.nombre || "Mando"} es ahora el principal`);
        }
    });
    const cambiarJugadores = () => conBloqueo(async () => {
        const nuevo = await call("ciclar", "max");
        setEst(nuevo);
        if (nuevo.aviso)
            avisar(nuevo.aviso);
        const n = Number(nuevo.prefs.JUGADORES_MAX);
        setPulsoMando(n);
        setTimeout(() => setPulsoMando(0), 520);
    });
    const elegirIntegrado = (modo) => conBloqueo(async () => {
        const nuevo = await call("integrado_modo", modo);
        setEst(nuevo);
        if (nuevo.aviso)
            avisar(nuevo.aviso);
    });
    // la tarjeta cicla: Jugador 1 -> Ultimo jugador -> Apagado
    const siguienteIntegrado = () => {
        const orden = ["primero", "ultimo", "ignorar"];
        const i = orden.indexOf(p.ORDEN_INTEGRADO);
        return orden[(i + 1) % orden.length];
    };
    const aplicar = () => conBloqueo(async () => {
        const r = await call("aplicar_todo");
        abrirVentana(r.ok ? "Aplicar: hecho" : "Aplicar: con problemas", r.salida);
        await refrescar();
    });
    const verLog = () => conBloqueo(async () => {
        const r = await call("ver_log");
        abrirVentana("Log (lo mas reciente arriba)", r.salida, true);
    });
    const instalar = () => conBloqueo(async () => {
        const r = await call("instalar_scripts");
        abrirVentana(r.ok ? "Scripts instalados" : `Error instalando (${r.exit})`, r.salida);
        await refrescar();
    });
    const restaurarTodo = () => {
        DFL.showModal(SP_JSX.jsx(DFL.ConfirmModal, { strTitle: "Restaurar todo", strDescription: "Se restaurara la configuracion anterior de Eden, Dolphin y Cemu, " +
                "se quitaran las preferencias del plugin y se desactivara el hook " +
                "de ES-DE.\n\n" +
                "Los emuladores deben estar cerrados. Se guarda una copia del " +
                "estado actual.\n\n" +
                "Podras reactivar el hook con el boton de arriba.", strOKButtonText: "Restaurar", strCancelButtonText: "Cancelar", onOK: () => {
                void conBloqueo(async () => {
                    const r = await call("restaurar_todo");
                    abrirVentana(r.ok ? "Restaurado" : "Restaurado con problemas", r.salida);
                    await refrescar();
                });
            }, onCancel: () => { } }));
    };
    if (!est) {
        return (SP_JSX.jsx(DFL.PanelSection, { title: "N.E.C.A", children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: { opacity: 0.8 }, children: "Leyendo mandos..." }) }) }));
    }
    const p = est.prefs;
    const integrado = est.mandos.find((m) => m.clase === "Integrado") ?? null;
    const externos = est.mandos.filter((m) => m.clase !== "Integrado");
    const integradoNombre = integrado?.nombre ?? "";
    const maquinaNombre = nombreMaquina(est.maquina);
    const mostrarIntegrado = Boolean(integrado) || Boolean(maquinaNombre);
    const acento = C.azul;
    return (SP_JSX.jsxs("div", { className: "ede-panel", style: {
            "--ede-acento": acento,
            "--ede-acento-halo": hexA(acento, 0.45),
        }, children: [SP_JSX.jsx("style", { children: ESTILOS }), !est.instalado || est.desactualizado || !est.hook ? (SP_JSX.jsx(DFL.PanelSection, { title: !est.instalado
                    ? "Primer uso"
                    : !est.hook
                        ? "Hook desactivado"
                        : est.reparar
                            ? "Reparar"
                            : "Actualizar", children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(BotonAccion, { color: C.verde, icono: SP_JSX.jsx(FaDownload, { size: 16 }), texto: !est.instalado
                            ? "Instalar scripts"
                            : !est.hook
                                ? "Reactivar hook"
                                : est.reparar
                                    ? "Reparar instalación"
                                    : "Actualizar scripts", onClick: instalar }) }) })) : null, est.scripts_nuevos ? (SP_JSX.jsx(DFL.PanelSection, { children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(Aviso, { tono: "info", children: "Scripts reci\u00E9n instalados. Cierra el juego y vuelve a abrirlo (o pulsa \u00ABAplicar\u00BB) para que se aplique la versi\u00F3n nueva." }) }) })) : null, est.esde === false ? (SP_JSX.jsx(DFL.PanelSection, { children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(Aviso, { tono: "atencion", children: "ES-DE: activa \u00ABOther settings \u2192 Enable custom event scripts\u00BB. Sin eso no se aplica al lanzar el juego." }) }) })) : null, SP_JSX.jsx(DFL.PanelSection, { children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: {
                            display: "flex",
                            flexWrap: "wrap",
                            gap: "6px",
                            width: "100%",
                        }, children: [maquinaNombre ? (SP_JSX.jsx(ChipEstado, { color: acento, icono: SP_JSX.jsx(IconoMaquina, { maquina: est.maquina, nombre: integradoNombre, size: 12 }), texto: maquinaNombre })) : null, SP_JSX.jsx(ChipEstado, { color: C.azul, icono: SP_JSX.jsx(FaGamepad, { size: 11 }), texto: `${est.mandos.length} ${est.mandos.length === 1 ? "mando" : "mandos"}` }), SP_JSX.jsx(ChipEstado, { color: C.violeta, icono: SP_JSX.jsx(FaFileAlt, { size: 11 }), texto: `v${est.version}` }), SP_JSX.jsx(ChipEstado, { color: est.hook ? C.verde : C.rojo, icono: est.hook ? SP_JSX.jsx(FaCheck, { size: 11 }) : SP_JSX.jsx(FaBan, { size: 11 }), texto: est.hook ? "hook OK" : "sin hook" })] }) }) }), SP_JSX.jsx(DFL.PanelSection, { children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(BotonTarjeta, { onClick: cambiarJugadores, children: SP_JSX.jsxs("div", { className: "ede-tarjeta", style: {
                                ...estiloTarjeta(acento),
                                display: "flex",
                                alignItems: "center",
                                gap: "10px",
                                width: "100%",
                                padding: "11px 12px",
                            }, children: [SP_JSX.jsx("span", { style: { fontWeight: 700, fontSize: "0.82em" }, children: "Mandos" }), SP_JSX.jsx("div", { style: {
                                        marginLeft: "auto",
                                        display: "flex",
                                        alignItems: "center",
                                        gap: "7px",
                                    }, children: [1, 2, 3, 4].map((n) => {
                                        const on = n <= Number(p.JUGADORES_MAX);
                                        return (SP_JSX.jsx("span", { className: `ede-slot ${on ? "on" : "off"}${pulsoMando === n ? " pulso" : ""}`, style: on ? { color: COLOR_JUGADOR[n - 1] } : undefined, children: SP_JSX.jsx(FaGamepad, { size: 15 }) }, n));
                                    }) })] }) }) }) }), SP_JSX.jsxs(Seccion, { titulo: "Mandos", color: acento, icono: SP_JSX.jsx(FaGamepad, { size: 13 }), abierta: true, accion: SP_JSX.jsxs("span", { style: { display: "flex", alignItems: "center", gap: "6px" }, children: [SP_JSX.jsx(BotonIcono, { titulo: "Asignaci\u00F3n", icono: SP_JSX.jsx(FaFileAlt, { size: 12 }), onClick: () => abrirAsignacion(est.planes, setEst) }), SP_JSX.jsx(BotonIcono, { titulo: "Recargar mandos", icono: SP_JSX.jsx(FaSyncAlt, { size: 12 }), onClick: () => conBloqueo(refrescar) })] }), children: [!mostrarIntegrado && externos.length === 0 ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: { opacity: 0.8 }, children: "No se detecta ningun mando. Enciende el mando y pulsa Recargar." }) })) : (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: {
                                display: "grid",
                                gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                                gap: "6px",
                                width: "100%",
                            }, children: [mostrarIntegrado ? (SP_JSX.jsx("div", { className: "ede-celda", style: {
                                        minWidth: 0,
                                        maxWidth: "100%",
                                        borderRadius: "16px",
                                    }, children: SP_JSX.jsx(TarjetaIntegrado, { icono: SP_JSX.jsx(IconoMaquina, { maquina: est.maquina, nombre: integradoNombre }), jugador: integrado?.jugador ?? null, modo: p.ORDEN_INTEGRADO, detectado: Boolean(integrado), onClick: () => elegirIntegrado(siguienteIntegrado()) }) })) : null, externos.map((m) => (SP_JSX.jsx("div", { className: "ede-celda", style: {
                                        minWidth: 0,
                                        maxWidth: "100%",
                                        borderRadius: "16px",
                                    }, children: SP_JSX.jsx(MandoCuadrado, { m: m, mostrarMac: true, destello: destello === m.serie, onClick: () => tocarMando(m) }) }, `${m.guid}-${m.puerto}`)))] }) })), aviso ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(Aviso, { tono: "atencion", onClick: limpiarAviso, children: aviso }) })) : null, est.ds_conectados > Number(p.JUGADORES_MAX) ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: { fontSize: "0.68em", color: C.dorado }, children: ["Se configuran ", p.JUGADORES_MAX, " de ", est.ds_conectados, " mandos. Cambialo en Ajustes \u2192 Mandos a configurar."] }) })) : null, est.mandos.length > 1 ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: {
                                display: "flex",
                                alignItems: "center",
                                gap: "6px",
                                fontSize: "0.68em",
                                opacity: 0.6,
                            }, children: [SP_JSX.jsx(GlifoA, {}), " vibrar \u00B7 dos toques seguidos = mando principal"] }) })) : null] }), SP_JSX.jsx(Seccion, { titulo: "Ajustes", color: C.violeta, icono: SP_JSX.jsx(FaSlidersH, { size: 12 }), abierta: Boolean(abiertas.ajustes), onToggle: () => toggle("ajustes"), children: SP_JSX.jsxs(Rejilla, { children: [SP_JSX.jsx("div", { className: "ede-celda", children: SP_JSX.jsx(TarjetaAccion, { color: C.verde, icono: SP_JSX.jsx(FaCheck, { size: 17 }), anim: "pop", titulo: "Aplicar", detalle: "Los 3", onClick: aplicar }) }), SP_JSX.jsx("div", { className: "ede-celda", children: SP_JSX.jsx(TarjetaAccion, { color: C.rojo, icono: SP_JSX.jsx(FaUndo, { size: 16 }), anim: "giro", titulo: "Restaurar", detalle: "Todo", onClick: restaurarTodo }) }), SP_JSX.jsx("div", { className: "ede-celda", children: SP_JSX.jsx(TarjetaAccion, { color: C.turquesa, icono: SP_JSX.jsx(FaFileAlt, { size: 16 }), anim: "barrido", titulo: "Ver log", detalle: "log.txt", onClick: verLog }) })] }) })] }));
}
var index = definePlugin(() => {
    return {
        name: "N.E.C.A",
        titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "N.E.C.A" }),
        content: SP_JSX.jsx(Content, {}),
        icon: SP_JSX.jsx(FaGamepad, {}),
        onDismount() {
            console.log("N.E.C.A descargado");
        },
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
