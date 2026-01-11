import { app, h, Dispatch } from "hyperapp";

interface State {
  clickEnabled: boolean;
  liked: boolean;
  likeUrl: string;
  visible: boolean;
}

const sendRequest = (url: string, method: string) => {
  return fetch(url, {
    method: method,
    credentials: "same-origin",
    headers: new Headers({
      'X-CSRF-Token': getCsrfToken()
    })
  });
};

const getCsrfToken = () => {
  const tokenDom = document.querySelector("meta[name=csrf-token]");
  if (tokenDom) {
    return tokenDom.getAttribute("content") || "";
  } else {
    return "";
  }
}

const Enable = (state: State, clickEnabled: boolean) => ({ ...state, clickEnabled });
const SetIcon = (state: State, liked: boolean) => ({ ...state, liked });
const Like = (state: State) => [
  state,
  (dispatch: Dispatch<State>) => {
    dispatch(Enable, false);
    sendRequest(state.likeUrl, "POST")
      .then(response => {
        if (response.ok) {
          dispatch(SetIcon, true);
          dispatch(Enable, true);
        } else {
          response.json().then(data => {
            const message = data.error || data.message || "An error occurred";
            alert(message);
          }).catch(() => {
            alertError();
          });
          dispatch(SetIcon, false);
          dispatch(Enable, true);
        }
      }).catch(_ => {
        alertError();
        dispatch(Enable, true);
      });
  }
];
const Unlike = (state: State) => [
  state,
  (dispatch: Dispatch<State>) => {
    dispatch(Enable, false);
    sendRequest(state.likeUrl, "DELETE")
      .then(response => {
        if (response.ok) {
          dispatch(SetIcon, false);
          dispatch(Enable, true);
        } else {
          response.json().then(data => {
            const message = data.error || data.message || "An error occurred";
            alert(message);
          }).catch(() => {
            alertError();
          });
          dispatch(SetIcon, true);
          dispatch(Enable, true);
        }
      }).catch(_ => {
        alertError();
        dispatch(Enable, true);
      });
  }
];

const alertError = () =>
  alert("An unexpected error occurred. Please try again later.");

const init = (container: HTMLDivElement, likeUrl: string, liked: boolean, visible: boolean) => {
  app({
    init: {
      clickEnabled: true,
      liked: liked,
      likeUrl: likeUrl,
      visible: visible,
    } as State,
    view: (state) =>
      h("span", {
        className: `${state.visible ? "icon" : ""} ${
          state.liked ? "icon-liked" : "icon-like"
        } ${state.clickEnabled ? "" : "disabled"}`,
        // @ts-ignore
        onclick: (state, event) => {
          event.stopPropagation();
          if (state.clickEnabled) {
            if (state.liked) {
              return Unlike;
            } else {
              return Like;
            }
          } else {
            return state;
          }
        },
      }, []),
    node: container
  })
};

const container = document.querySelector<HTMLDivElement>("#like-component");
if (container && container.dataset.likeUrl) {
  const likeUrl = container.dataset.likeUrl;
  fetch(likeUrl, {
    credentials: "same-origin",
    headers: new Headers({
      'X-CSRF-Token': getCsrfToken()
    })
  }).then(response => response.json())
    .then(data => init(container, likeUrl, data.like.liked, true))
    .catch(_ => init(container, likeUrl, false, false));
}
