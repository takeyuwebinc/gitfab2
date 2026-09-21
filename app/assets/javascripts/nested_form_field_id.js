//= require jquery_nested_form

// nested_form は追加するフィールドの index にミリ秒単位の時刻を使う。同じミリ秒のうちに複数の
// フィールドを追加すると index が重なり、サーバーには重なった組の最後の 1 件しか届かない。
// カードの並べ替えの確定は、全カードぶんのフィールドを 1 回のループで追加するため、これに当たる。
// index を単調に増やして重ならないようにする。前回より時刻が進んでいれば、返す値は時刻のままになる。
// index は数字だけで、既存フィールドの index（0 からの連番）より大きい必要がある。nested_form は
// 入れ子の親の index を数字の並びとして探すため。
(function() {
  let lastFieldId = 0;
  window.nestedFormEvents.newId = function() {
    lastFieldId = Math.max(new Date().getTime(), lastFieldId + 1);
    return lastFieldId;
  };
})();
