// ArrayLoaderInterface
// Written in 2016 by Nate Stedman <nate@natestedman.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright and
// related and neighboring rights to this software to the public domain worldwide.
// This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along with
// this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

/// The sections used by an array loader interface controller.
internal enum Section: Int
{
    /// A section displaying a pull-to-refresh interface.
    case PreviousPagePull

    /// A section displaying an activity indicator cell while the previous page is loading.
    case PreviousPageActivity

    /// A section displaying the previous page's error, if any.
    case PreviousPageError

    /// A section displaying an optional custom header view.
    case CustomHeaderView

    /// A section displaying the values of the array loader.
    case Values

    /// A section displaying an activity indicator cell while the next page is loading.
    case NextPageActivity

    /// A section displaying the next page's error, if any.
    case NextPageError

    /// A section displaying a footer cell, shown after the next page has been completed.
    case NextPageCompleted
}
