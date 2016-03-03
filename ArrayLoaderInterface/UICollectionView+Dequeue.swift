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

extension UICollectionView
{
    /**
     Determines a reuse identifier for the cell type.

     - parameter cellClass: The cell type.
     */
    private func reuseIdentifier<T: UICollectionViewCell>(cellClass: T.Type) -> String
    {
        return "ArrayLoaderInterface-\(cellClass)"
    }

    /**
     Registers a cell class with the collection view.

     - parameter cellClass: The cell class to register.
     */
    internal func registerCellClass<T: UICollectionViewCell>(cellClass: T.Type)
    {
        registerClass(cellClass, forCellWithReuseIdentifier: reuseIdentifier(cellClass))
    }

    /**
     Dequeues a cell class from the collection view.

     - parameter cellClass:    The cell class to dequeue.
     - parameter forIndexPath: The index path to dequeue the cell for.
     */
    internal func dequeue<T: UICollectionViewCell>(cellClass: T.Type, forIndexPath: NSIndexPath) -> T
    {
        return dequeueReusableCellWithReuseIdentifier(reuseIdentifier(T.self), forIndexPath: forIndexPath) as! T
    }
}
