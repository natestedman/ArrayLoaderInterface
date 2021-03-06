// ArrayLoaderInterface
// Written in 2016 by Nate Stedman <nate@natestedman.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright and
// related and neighboring rights to this software to the public domain worldwide.
// This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along with
// this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

import UIKit

/// A plain collection view cell, used for the optional custom header view.
///
/// This needs to be a distinct class, in case `UICollectionViewCell` is used as a cell - otherwise, it might be
/// possible to add the custom header view to a cell, and not remove it correctly.
internal final class CustomHeaderViewCollectionViewCell: UICollectionViewCell {}
